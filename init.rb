#!/bin/env ruby
# encoding: utf-8

require 'redmine'
require 'gpgme'
require 'base64'
require 'mailer_patch'
require 'mail_handler_patch'

Redmine::Plugin.register :chiliproject_encrypted_email_notifications do
  name 'Chiliproject Encrypted Email Notifications'
  author 'Alexander Blum'
  description 'This plugin for ChiliProject enhances the security of email communication by ' +
    'encrypting/decrypting mails with GnuPG and filtering content of unencrypted mails'
  version '0.1'
  author_url 'mailto:a.blum@free-reality.net'
  url 'https://github.com/C3S/chiliproject_encrypted_email_notifications'
  settings(:default => {
    'cfEncrypt' => nil,
    'cfKey' => nil,
    'filteredMailFooter' => 'This message was filtered to enhance the protection of privacy.'
  }, :partial => 'settings/chiliproject_encrypted_email_notifications')
  project_module :chiliproject_encrypted_email_notifications do
    permission :block_email, {:chiliproject_encrypted_email_notifications => :show}
  end
end

# Sending Mals
Dispatcher.to_prepare do
  require_dependency 'mailer'
  Mailer.send(:include, MailerPatch)
end

# Recieving Mals
Dispatcher.to_prepare do
  require_dependency 'mail_handler'
  MailHandler.send(:include, MailHandlerPatch)
end
