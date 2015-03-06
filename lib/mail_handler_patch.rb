#!/bin/env ruby
# encoding: utf-8

module MailHandlerPatch

  def self.included(base) # :nodoc:

    base.send(:include, InstanceMethods)

    base.class_eval do
      alias_method_chain :receive, :decryption
      alias_method_chain :plain_text_body, :decryption
      alias_method_chain :add_attachments, :decryption
    end

  end

  module InstanceMethods

    def init_decryption()

      # configuration
      pgp_inline_filename_extensions = ['.pgp', '.gpg', '.asc']
      remove_attachments = [
        'signature.asc',            #applemail/gpgtools: signature
        '\w{1}x\w{8}.asc(.pgp|.gpg|.asc)?'    #thunderbird/enigmail: public key
      ]

      # flags
      @decryption = import_key_chiliuser.any? ? true : false

      # regex
      @regex_pgpmsg = /-----BEGIN PGP MESSAGE-----.*-----END PGP MESSAGE-----/m
      @regex_pgpext = Regexp.new pgp_inline_filename_extensions * "|" + "$"
      @regex_remove_attachments = Regexp.new "^" + remove_attachments * "|" + "$"

    end

    def receive_with_decryption(email)

      init_decryption
      receive_without_decryption(email)

    end

    def plain_text_body_with_decryption
      
      plain_text_body_without_decryption
      
      if @decryption
        parts = @email.parts.collect {|c| (c.respond_to?(:parts) && !c.parts.empty?) ? c.parts : c}.flatten
        case email_encryption(parts)
        when "PGP/MIME"

          Rails.logger.info "Encryption detected: PGP/MIME"

          # create new mail from encrypted part
          encrypted_part = parts.detect{|p| p.content_type.include? 'application/octet-stream'}
          encrypted_body = encrypted_part.body.to_s
          decrypted_body = decrypt(encrypted_body.match(@regex_pgpmsg)[0])
          decrypted_mail = TMail::Mail.parse(decrypted_body)
          decrypted_parts = decrypted_mail.parts.collect {
            |c| (c.respond_to?(:parts) && !c.parts.empty?) ? c.parts : c
          }.flatten
          if decrypted_parts.empty?
            decrypted_parts << decrypted_mail
          end

          # add plain/text part
          plain_text_part = decrypted_parts.detect {|p| p.content_type == 'text/plain'}
          @plain_text_body = plain_text_part.body.to_s.force_encoding("UTF-8").strip!
          decrypted_parts.try(:delete, plain_text_part)

          # add attachments
          decrypted_parts.each do |p|
            @email.parts.try(:push, p)
          end

          # delete PGP/MIME version identification and encrypted part
          version_id = parts.detect{|p| p.content_type.include? 'application/pgp-encrypted'}
          @email.parts.try(:delete, version_id)
          @email.parts.try(:delete, encrypted_part)

        when "PGP/INLINE"

          Rails.logger.info "Encryption detected: PGP/INLINE"

          # decrypt message
          @plain_text_body = decrypt(@plain_text_body.match(@regex_pgpmsg)[0]).force_encoding("UTF-8").strip!

        end
      end

      @plain_text_body

    end

    def add_attachments_with_decryption(obj)

      # delete certain files, which should not be attached
      if email.has_attachments?
        attachment_parts = email.parts.select {|p| p.attachment?(p) }
        email.attachments.each do |attachment|
          unless attachment.original_filename.match(@regex_remove_attachments).nil?
            attachment_part = attachment_parts.detect {
              |p| p.header['content-type'].try(:[], 'name') == attachment.original_filename
            }
            if attachment_part.present?
              email.parts.try(:delete, attachment_part)
              Rails.logger.info "Deleting Attachment (filtered out): #{attachment.original_filename}"
            end
          end
        end
      end


      if @decryption and email.has_attachments?
        attachment_parts = email.parts.select {|p| p.attachment?(p) }
        email.attachments.each do |attachment|
          unless attachment.original_filename.match(@regex_pgpext).nil?

            Rails.logger.info "Encrytped Attachment (Plain) detected"

            begin 

              # create new attachment
              filename = attachment.original_filename.gsub(@regex_pgpext, '')
              attachment.rewind
              file = TMail::Attachment.new()
              file.string = decrypt(attachment.string)
              file.class.class_eval { attr_accessor :original_filename, :content_type }
              file.original_filename = filename
              file.content_type = attachment.content_type

              # attach new attachment
              Attachment.create(
                :container => obj,
                :file => file,
                :filename => filename,
                :author => user,
                :content_type => attachment.content_type
              )

              # delete old attachment
              attachment_part = attachment_parts.detect {
                |p| p.header['content-disposition']['filename'] == attachment.original_filename 
              }
              email.parts.try(:delete, attachment_part)

            rescue => e

              # delete not decryptable attachment (probably signature)
              Rails.logger.warn "Deleting Attachment: #{attachment.original_filename}"
              attachment_part = attachment_parts.detect {
                |p| p.header['content-disposition']['filename'] == attachment.original_filename 
              }
              email.parts.try(:delete, attachment_part)

            end

          end
        end
      end

      add_attachments_without_decryption(obj)

    end

    def import_key_chiliuser()

      # get key from DB
      key = Setting.plugin_chiliproject_encrypted_email_notifications['chiliPrivateKey']
      # add key to keychain
      GPGME::Key.import(key) if key.to_s.strip.length != 0
      # retrieve key fom keychain
      gpg_key = GPGME::Key.find(:secret, Setting.plugin_chiliproject_encrypted_email_notifications['chiliEmail'])

    end

    def email_encryption(parts)

      # PGP/MIME, if headers match RFC 3156 and 'PGP MESSAGE' block found within encrypted part
      return "PGP/MIME" if @email.content_type == 'multipart/encrypted' and
        @email.header['content-type'].try(:[], 'protocol') == 'application/pgp-encrypted' and
        !!parts.detect{|p| p.content_type.include? 'application/octet-stream'}.try(:body).to_s.match(@regex_pgpmsg)

      # PGP/Inline, if 'PGP MESSAGE' block found within plain/text part
      return "PGP/INLINE" unless @plain_text_body.match(@regex_pgpmsg).nil?

      # NONE otherwise
      return "NONE"

    end

    def decrypt(text)

      dec = GPGME::Crypto.new.decrypt(text, { 
        :password => Setting.plugin_chiliproject_encrypted_email_notifications['chiliPrivateKeyPwd'] 
      }).to_s

    end

  end

end