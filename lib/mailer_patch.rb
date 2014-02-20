module MailerPatch

	def self.included(base) # :nodoc:

		base.send(:include, InstanceMethods)

		base.class_eval do
			alias_method_chain :render_multipart, :encryption
		end

	end

	module InstanceMethods

		def init_encryption(method_name)

			return "NOT IMPLEMENTED" unless ['issue_add', 'issue_edit'].include?(method_name)

			# get project of object
			project = @body[:issue].project if ['issue_add', 'issue_edit'].include?(method_name)

			# configuration
			@filteredMailFooter = Setting.plugin_chiliproject_encrypted_email_notifications['filteredMailFooter']
			filPub = Setting.plugin_chiliproject_encrypted_email_notifications['filterPublic']
			filPri = Setting.plugin_chiliproject_encrypted_email_notifications['filterNonpublic']
			encPub = Setting.plugin_chiliproject_encrypted_email_notifications['encryptPublic']
			encPri = Setting.plugin_chiliproject_encrypted_email_notifications['encryptNonpublic']
			isPub = project.is_public
			isPri = !(isPub)

			# flags
			@encryption = {
				'encrypt' => false,
				'filter' => false,
			}
			@filter = {
				'HeaderProjectTitle' => false,
			    'HeaderIssueAuthor' => false,
			    'HeaderIssueAssignee' => false,
			    'SubjectProjectTitle' => false,
			    'SubjectIssueTracker' => false,
			    'SubjectIssueStatus' => false,
			    'SubjectIssueTitle' => false,
			    'BodyProjectDescription' => false,
			    'BodyProjectTitle' => false,
			    'BodyIssueAuthor' => false,
			    'BodyIssueDetails' => false,
			    'BodyIssueNotes' => false,
			    'BodyIssueTitle' => false,
			    'BodyIssueAttributes' => false
			}

			# set flags according to settings
			if (isPub and filPub != "none") or (isPri and filPri != "none")
				if (isPub and filPub == "all") or (isPri and filPri == "all") or project.module_enabled?('chiliproject_encrypted_email_notifications')
					@encryption['filter'] = true
					@filter = {
						'HeaderProjectTitle' => Setting.plugin_chiliproject_encrypted_email_notifications['removeHeaderProjectTitle'] ? true : false ,
					    'HeaderIssueAuthor' => Setting.plugin_chiliproject_encrypted_email_notifications['removeHeaderIssueAuthor'] ? true : false ,
					    'HeaderIssueAssignee' => Setting.plugin_chiliproject_encrypted_email_notifications['removeHeaderIssueAssignee'] ? true : false ,
					    'SubjectProjectTitle' => Setting.plugin_chiliproject_encrypted_email_notifications['removeSubjectProjectTitle'] ? true : false ,
					    'SubjectIssueTracker' => Setting.plugin_chiliproject_encrypted_email_notifications['removeSubjectIssueTracker'] ? true : false ,
					    'SubjectIssueStatus' => Setting.plugin_chiliproject_encrypted_email_notifications['removeSubjectIssueStatus'] ? true : false ,
					    'SubjectIssueTitle' => Setting.plugin_chiliproject_encrypted_email_notifications['removeSubjectIssueTitle'] ? true : false ,
					    'BodyProjectDescription' => Setting.plugin_chiliproject_encrypted_email_notifications['removeBodyProjectDescription'] ? true : false ,
					    'BodyProjectTitle' => Setting.plugin_chiliproject_encrypted_email_notifications['removeBodyProjectTitle'] ? true : false ,
					    'BodyIssueAuthor' => Setting.plugin_chiliproject_encrypted_email_notifications['removeBodyIssueAuthor'] ? true : false ,
					    'BodyIssueDetails' => Setting.plugin_chiliproject_encrypted_email_notifications['removeBodyIssueDetails'] ? true : false ,
					    'BodyIssueNotes' => Setting.plugin_chiliproject_encrypted_email_notifications['removeBodyIssueNotes'] ? true : false ,
					    'BodyIssueTitle' => Setting.plugin_chiliproject_encrypted_email_notifications['removeBodyIssueTitle'] ? true : false ,
					    'BodyIssueAttributes' => Setting.plugin_chiliproject_encrypted_email_notifications['removeBodyIssueAttributes'] ? true : false 
					}
				end
			end
			if (isPub and encPub == "project") or (isPri and encPri == "project")
				if project.module_enabled?('chiliproject_encrypted_email_notifications')
					@encryption['encrypt'] = true if ( 
						User.find_by_mail(@recipients[0]).try(
							:custom_value_for, 
							Setting.plugin_chiliproject_encrypted_email_notifications['cfEncrypt']
						).try(:value) == '1' 
					)
				end
			end
			@encryption['encrypt'] = false if ((isPub and encPub == "none") or (isPri and encPri == "none"))
			@encryption['encrypt'] = true if ((isPub and encPub == "all") or (isPri and encPri == "all"))

			# if mail should be enctypted, import and retrieve key, to check for capability
			if @encryption['encrypt']
				import_key_user(@recipients).any? ? @encryption['filter'] = false :	@encryption['encrypt'] = false
			end

		end

		def render_multipart_with_encryption(method_name, body)

			if init_encryption(method_name) == "NOT IMPLEMENTED"
				render_multipart_without_encryption(method_name, body)
			else
				# filter subject and header
				if @encryption['encrypt'] or @encryption['filter']
					s = "["
					s << "#{@body[:issue].project.name} - " unless @filter['SubjectProjectTitle']
					s << "#{@body[:issue].tracker.name} " unless @filter['SubjectIssueTracker']
					s << "##{@body[:issue].id}]"
				    s << " (#{@body[:issue].status.name})" unless @filter['SubjectIssueStatus']
				    s << " #{@body[:issue].subject}" unless @filter['SubjectIssueTitle']
				    @subject = s
				    @headers['X-ChiliProject-Project'] = nil if @filter['HeaderProjectTitle']
				    @headers['X-ChiliProject-Issue-Author'] = nil if @filter['HeaderIssueAuthor']
				    @headers['X-ChiliProject-Issue-Assignee'] = nil if @filter['HeaderIssueAssignee']
				end
				# render encrypted mail
				if @encryption['encrypt']
					Rails.logger.info "Trying to send encrypted mail"
					render_encrypted(method_name);
				# render filtered mail
				elsif @encryption['filter']
					Rails.logger.info "Trying to send filtered mail"
				    render_filtered(method_name, body)
				# render default mail
				else 
					Rails.logger.info "Trying to send unfiltered, unencrypted mail"
					render_multipart_without_encryption(method_name, body)
				end
			end

		end

		def import_key_user(recipient)

			# get key from DB
			key = User.find_by_mail(recipient[0]).try(
				:custom_value_for, 
				Setting.plugin_chiliproject_encrypted_email_notifications['cfKey']
			).try(:value)
			# add key to keychain
			GPGME::Key.import(key) if key.to_s.strip.length != 0
			# retrieve key fom keychain
			gpg_key = GPGME::Key.find(:public, recipient)

		end

		def encrypt(text, recipient)

			enc = GPGME::Crypto.new.encrypt(text, { :recipients => recipient, :always_trust => true } ).to_s
			enc_b64 = Base64.encode64(enc).chomp("\n")
			# at least one trailing "=" seems to be needed for the interpretation by enigmail 
			enc_b64 += '====' unless enc_b64[-1] == '='
			enc_b64

		end

		def render_encrypted(method_name)

			# render mail matching RFC 3156
			self.content_type "multipart/encrypted; protocol=\"application/pgp-encrypted\""
			self.part 'application/pgp-encrypted' do |p|
				p.headers['Content-Description'] = 'PGP/MIME Versions Identification'
				p.transfer_encoding = '7bit'
				p.charset = "UTF-8"
				p.body = "Version: 1\n"
			end
			self.part 'application/octet-stream; name="encrypted.asc"' do |p|
				p.headers['Content-Description'] = 'OpenPGP encrypted message'
				p.headers['Content-Disposition'] = 'inline; filename="encrypted.asc"'
				p.transfer_encoding = '7bit'
				p.charset = "UTF-8"
				p.body render(
					:file => "#{method_name}.text.plain.rhtml", 
					:body => self.body, 
					:layout => 'mailer.text.plain.erb'
				)
				p.body "-----BEGIN PGP MESSAGE-----\nCharset: UTF-8\n\n" +
					encrypt("Content-Type: text/plain; charset=UTF-8\n\n" + p.body.to_s, self.recipients) +
					"\n-----END PGP MESSAGE-----\n"
			end
			#self.body.preamble "This is an OpenPGP/MIME encrypted message (RFC 2440 and 3156)"
			self.body = {}

		end

		def render_filtered(method_name, body)

			# filter mail using templates provided by this plugin
			if Setting.plain_text_mail?
				content_type "text/plain"
				body render(
					:file => "#{method_name}.text.plain.filtered.rhtml", 
					:body => body, 
					:layout => 'mailer.text.plain.erb'
				)
			else
				content_type "multipart/alternative"
				part :content_type => "text/plain", :body => render(
					:file => "#{method_name}.text.plain.filtered.rhtml", 
					:body => body, 
					:layout => 'mailer.text.plain.erb'
				)
				part :content_type => "text/html", :body => render_message(
					"#{method_name}.text.html.filtered.rhtml", 
					body
				)
			end

		end

	end

end
