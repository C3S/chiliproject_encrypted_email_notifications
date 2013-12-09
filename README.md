ChiliProject Encrypted Email Notifications
==========================================

A plugin for ChiliProject to enhance the security of email communication by

* encrypting/decrypting mails with GnuPG
* filtering content of unencrypted mails 


Details
-------

### Notification Mails affected

* New Issue
* Edit Issue

### Email format supported

* mails send to user:
  * PGP/MIME
* mails received from user: 
  * PGP/MIME
  * PGP/Inline (filename extensions for attachments: '.pgp', '.gpg', '.asc')

### Filters available

* Header
  * Project Title
  * Issue Author
  * Issue Assignee
* Subject
  * Project Title
  * Issue Type
  * Issue Status
  * Issue Title
* Body
  * Project Title
  * Project Description
  * Issue Author
  * Issue Details
  * Issue Notes
  * Issue Title
  * Issue Attributes


Dependencies
------------

* gpg (http://www.gnupg.org/download/)
* gpgme (https://github.com/ueno/ruby-gpgme)
* rails < 3


Compatibility
-------------

This plugin has been tested with 

* GnuPG 1.4.11 / ChiliProject 3.8.0 / Ruby 1.9.3 / Rails 2.3.18 / gpgme 2.0.2

This plugin might essentially be compatible with Redmine, but may need little tweaks.


Configuration
-------------

### Server Admin

1. Make sure, the user running ChiliProject is able to execute gpg and that it's local keychain has been initialized  
   e.g. log in as the user running ChiliProject and try `$gpg --list-keys`
2. Install gem 'gpgme'  
   e.g. add `gem 'gpgme'` to `/path/to/chiliroject/Gemfile` and execute `$bundle update`
3. Place the plugin into  `/path/to/chiliproject/vendor/plugins` . The name of the plugin's directory should be `chiliproject_encrypted_email_notifications`.
4. Restart ChiliProject (e.g. restart apache).

### ChiliProject Admin

1. Log into ChiliProject as admin and **create two custom fields** (memorize their corresponding IDs):
  * "PGP Public Key" *(Long text)*
  * "Enable Mail Encryption" *(Boolean)*

2. **Configure** the Plugin *(Administration / Plugins : Chiliproject Encrypted Mail Notifications > Configure)*

  1. Configure **Plugin Configuration**
    * Neccessary for encryption
      * Custom Field ID of "Enable Mail Encryption"
      * Custom Field ID of "PGP Public Key"
    * Neccessary for decryption
      * Emailaddress of Chiliuser
      * PGP Private Key for Emailadress of Chiliuser  
        **WARNING**: Don't use a private key here, which should never be compromised, as the secret key is written to the database in cleartext. PGP is just used for secure communication, not secure storage of your data, so if your database got hacked, the secret key does not matter anyway
      * Password for PGP Private Key for Emailadress of Chiliuser
    * Optional
      * Enter a message, which is added to the footer of filtered emails (e.g. instructions for encryption)

  2. Configure **Global Settings**  
    * Filter emails of (non-)public projects:  
      * *project dependend*: Filtering is active for (non-)public projects, if module is active for the project  
      * *all*: Filtering is active for all (non-)public projects, regardless of module activation  
      * *none*: Filtering is inactive for all (non-)public projects, regardless of module activation  
    * Encrypt emails of (non-)public projects:  
      * *project dependend*: Encryption is active for (non-)public projects, if module is active for the project and user has enabled mail encryption  
      * *all*: Encryption is active for (non-)public projects, regardless of module activation and user setting, if there's a key corresponding to email of user in the local keychain  
      * *none*: Encryption is inactive for (non-)public projects, regardless of module activation

  3. Configure **Available Filters**  
     *NOTICE*: issue updates by email might rely on header/subject
    * *Header*: Applies to both filtered and encrypted mails  
    * *Subject*: Applies to both filtered and encrypted mails  
    * *Body*: Applies only to filtered mails  

  4. Apply your settings

3. Configure Projects  
   *NOTICE*: plugin settings may override module activation
  * On *'Administration / Project / Modules'*, check module "Chiliproject Encrypted Mail Notifications" for module activation, where neccessary  


### User

1. Log into ChiliProject and update your profile
2. "*PGP Public Key*": Enter your PGP Public Key   
   Format: ASCII, from "`-----BEGIN PGP PUBLIC KEY BLOCK-----`" to "`-----END PGP PUBLIC KEY BLOCK-----`", linebreaks and comments should not matter
3. Check "*Enable Mail Encryption*", if you want to use mail encryption
4. Save your profile


Possible improvements
---------------------

* Add RegEx for Custom Field "PGP Public Key" to prevent syntax errors  
  RegEx would be `\^s*?-----BEGIN PGP PUBLIC KEY BLOCK-----.*-----END PGP PUBLIC KEY BLOCK-----\s*?$\m`, but there seem to be no way to enable multiline mode in Custom Field RegEx
* Add more notification mails affected (e.g. Wiki, etc.)
* Integrate the Custom Fields into this plugin
* Add a field "PGP Public Key for Emailadress of Chiliuser" to plugin settings and offer key download to user on profile
* Add option to enforce verification of signature corresponding to user for incoming mails
* Get Emailadress of Chiliuser from field 'Emission email address' in ChiliProject Settings for 'Email notifications'
* Test compatibility with Redmine and adjust code, where neccessary
* Add more languages
* Add tests


Links
-----

* [C3S](https://www.c3s.cc/) (cultural commons collecting society)
* [GPG](http://www.gnupg.org/gph/en/manual/x56.html) (reference)
* [ActionMailer](http://apidock.com/rails/ActionMailer/Base) (reference)
* [TMail](http://tmail.rubyforge.org/rdoc/index.html) (reference)
* [Base64](http://ruby-doc.org/stdlib-2.0.0/libdoc/base64/rdoc/Base64.html) (reference)
* [GPGME](http://www.ruby-doc.org/gems/docs/b/benburkert-gpgme-0.1.5/index.html) (reference)
* [PGP/MIME](http://www.ietf.org/rfc/rfc3156.txt) (RFC)
* [Redmine Email Notification Content Filter](http://www.redmine.org/plugins/redmine_email_notification_content_filter) (plugin)
* [PGP Formats](http://binblog.info/2008/03/12/know-your-pgp-implementation/) (explanation)
* [OpenPGP vs. S/MIME (de)](http://www.kes.info/archiv/online/01-01-60-SMIMEvsOpenPGP.htm) (comparison)
* [Gem OpenPGP for Ruby > 3](https://jkraemer.net/openpgp-mail-encryption-with-ruby) (gem)


Credits
-------

This plugin was inspired by the plugin [Redmine Email Notification Content Filter](http://www.redmine.org/plugins/redmine_email_notification_content_filter)

* Author: [Alexander Blum](https://github.com/timegrid)


License
-------

Copyright 2013 Alexander Blum

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.