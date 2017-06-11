#
# Ubiquitous Moodle
#
# @author Luke Carrier <luke@carrier.im>
# @copyright 2016 Luke Carrier
#

include:
  - base

#
# Dependencies
#

ruby:
  pkg.installed:
    - pkgs:
      - build-essential
      - libsqlite3-dev
      - ruby-dev

#
# MailCatcher
#

mailcatcher:
  user.present:
    - fullname: MailCatcher user
    - shell: /bin/bash
    - home: /var/mailcatcher
    - gid_from_name: true
  cmd.run:
    - name: gem install --user-install mailcatcher
    - runas: mailcatcher
    - require:
      - user: mailcatcher
  file.managed:
    - name: /etc/systemd/system/mailcatcher.service
    - source: salt://mail-debug/systemd/mailcatcher.service
    - user: root
    - group: root
    - mode: 0644
  service.running:
    - enable: True
    - require:
      - file: /etc/systemd/system/mailcatcher.service
      - cmd: mailcatcher
