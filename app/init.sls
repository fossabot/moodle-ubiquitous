#
# Ubiquitous Moodle
#
# @author Luke Carrier <luke@carrier.im>
# @copyright 2016 Luke Carrier
#

include:
  - base
  - nginx-base

#
# nginx
#

/etc/logrotate.d/nginx:
  file.managed:
    - source: salt://app/logrotate/nginx
    - user: root
    - group: root
    - mode: 0644

/etc/nginx/sites-extra:
  file.directory:
    - user: root
    - group: root
    - mode: 755

#
# PHP
#

php.packages:
  pkg.installed:
    - pkgs:
      - php7.0-dev
      - php7.0-cli
      - php7.0-curl
      - php7.0-fpm
      - php7.0-gd
      - php7.0-intl
      - php7.0-json
      - php7.0-mbstring
      - php7.0-mcrypt
      - php7.0-opcache
      - php7.0-pdo
      - php7.0-pgsql
      - php7.0-soap
      - php7.0-xml
      - php7.0-xmlrpc
      - php7.0-zip

/etc/php/7.0/fpm/php-fpm.conf:
  file.managed:
    - source: salt://app/php-fpm/php-fpm.conf
    - user: root
    - group: root
    - mode: 0644

/etc/php/7.0/fpm/pools-available:
  file.directory:
    - user: root
    - group: root
    - mode: 755

/etc/php/7.0/fpm/pools-enabled:
  file.directory:
    - user: root
    - group: root
    - mode: 755

/etc/php/7.0/fpm/pools-extra:
  file.directory:
    - user: root
    - group: root
    - mode: 755

/etc/php/7.0/fpm/pool.d:
  file.absent:
    - require:
      - pkg: php.packages
      - file: /etc/php/7.0/fpm/php-fpm.conf
      - file: /etc/php/7.0/fpm/pools-enabled

/var/log/php7.0-fpm:
  file.directory:
    - user: root
    - group: root
    - mode: 0755

/etc/logrotate.d/php7.0-fpm:
  file.managed:
    - source: salt://app/logrotate/php7.0-fpm
    - user: root
    - group: root
    - mode: 0644

{% if pillar['systemd']['apply'] %}
php-fpm:
  service.running:
    - name: php7.0-fpm
    - enable: True
    - require:
      - pkg: nginx
      - pkg: php.packages

php-fpm.reload:
  service.running:
    - name: php7.0-fpm
    - reload: True
{% endif %}

#
# SQL Server drivers for PHP
#

php.sqlsrv.repo:
  pkgrepo.managed:
    - file: /etc/apt/sources.list.d/mssql-release.list
    - humanname:
    - name: deb [arch=amd64] https://packages.microsoft.com/ubuntu/16.04/prod xenial main
    - key_url: https://packages.microsoft.com/keys/microsoft.asc

php.sqlsrv.msodbcsql.license:
  debconf.set:
    - name: 'msodbcsql'
    - data:
        'msodbcsql/accept_eula': { 'type': 'boolean', 'value': True }

php.sqlsrv.deps:
  pkg.latest:
    - pkgs:
      - build-essential
      - gcc
      - g++
      - unixodbc-dev
    - require:
      - pkgrepo: php.sqlsrv.repo

# Temporarily work around ODBC client packaging failing to check the debconf
# database and requiring ACCEPT_EULA environment variable to be set at install
# time.
#
# See https://connect.microsoft.com/SQLServer/Feedback/Details/3105172
php.sqlsrv.pkgs:
  cmd.run:
    - name: apt-get install --assume-yes msodbcsql
    - env:
      - ACCEPT_EULA: Y
    - unless: dpkg -l | grep msodbcsql
    - require:
      - pkg: php.sqlsrv.deps

{% for extension, priority in {'sqlsrv': 20, 'pdo_sqlsrv': 20}.items() %}
php.sqlsrv.{{ extension }}.pecl:
  pecl.installed:
    - name: {{ extension }}

php.sqlsrv.{{ extension }}.ini.available:
  file.managed:
    - name: /etc/php/7.0/mods-available/{{ extension }}.ini
    - source: salt://app/php/extension.ini.jinja
    - template: jinja
    - context:
      extension: {{ extension }}
      priority: {{ priority }}

{% for sapi in ['cli', 'fpm'] %}
php.sqlsrv.{{ extension }}.ini.enabled.{{ sapi }}:
  file.symlink:
    - name: /etc/php/7.0/{{ sapi }}/conf.d/{{ priority }}-{{ extension }}.ini
    - target: /etc/php/7.0/mods-available/{{ extension }}.ini
{% if pillar['systemd']['apply'] %}
    - require_in:
      - service: php-fpm.reload
{% endif %}
{% endfor %}
{% endfor %}

#
# Supporting packages
#

ghostscript:
  pkg.installed

#
# Required directories
#

{% for home_directory in pillar['system']['home_directories'] %}
homes.{{ home_directory }}:
  file.directory:
    - name: {{ home_directory }}
    - user: root
    - group: root
    - mode: 755

{% if pillar['acl']['apply'] %}
homes.{{ home_directory }}.acl:
  acl.present:
    - name: {{ home_directory }}
    - acl_type: user
    - acl_name: {{ pillar['nginx']['user'] }}
    - perms: rx
{% endif %}
{% endfor %}

#
# Moodle platforms
#

{% for domain, platform in salt['pillar.get']('platforms', {}).items() %}
moodle.{{ domain }}.user:
  user.present:
    - name: {{ platform['user']['name'] }}
    - fullname: {{ domain }}
    - shell: /bin/bash
    - home: {{ platform['user']['home'] }}
    - gid_from_name: true

moodle.{{ domain }}.home:
  file.directory:
    - name: {{ platform['user']['home'] }}
    - user: {{ platform['user']['name'] }}
    - group: {{ platform['user']['name'] }}
    - mode: 0770
    - require:
      - user: {{ platform['user']['name'] }}

{% if pillar['acl']['apply'] %}
moodle.{{ domain }}.home.acl:
  acl.present:
    - name: {{ platform['user']['home'] }}
    - acl_type: user
    - acl_name: {{ pillar['nginx']['user'] }}
    - perms: rx
    - require:
      - file: moodle.{{ domain }}.home

moodle.{{ domain }}.home.acl.default:
  acl.present:
    - name: {{ platform['user']['home'] }}
    - acl_type: default:user
    - acl_name: {{ pillar['nginx']['user'] }}
    - perms: rx
    - require:
      - file: moodle.{{ domain }}.home
{% endif %}

moodle.{{ domain }}.releases:
  file.directory:
    - name: {{ platform['user']['home'] }}/releases
    - makedirs: True
    - user: {{ platform['user']['name'] }}
    - group: {{ platform['user']['name'] }}
    - mode: 0770
    - require:
      - file: moodle.{{ domain }}.home

{% if pillar['acl']['apply'] %}
moodle.{{ domain }}.releases.acl:
  acl.present:
    - name: {{ platform['user']['home'] }}/releases
    - acl_type: user
    - acl_name: {{ pillar['nginx']['user'] }}
    - perms: rx
    - require:
      - file: moodle.{{ domain }}.releases

moodle.{{ domain }}.releases.acl.default:
  acl.present:
    - name: {{ platform['user']['home'] }}/releases
    - acl_type: default:user
    - acl_name: {{ pillar['nginx']['user'] }}
    - perms: rx
    - require:
      - file: moodle.{{ domain }}.home
{% endif %}

moodle.{{ domain }}.data:
  file.directory:
    - name: {{ platform['user']['home'] }}/data
    - user: {{ platform['user']['name'] }}
    - group: {{ platform['user']['name'] }}
    - mode: 0770
    - require:
      - file: moodle.{{ domain }}.home

moodle.{{ domain }}.localcache:
  file.directory:
    - name: {{ platform['user']['home'] }}/data/localcache
    - user: {{ platform['user']['name'] }}
    - group: {{ platform['user']['name'] }}
    - mode: 0770
    - require:
      - file: moodle.{{ domain }}.data

moodle.{{ domain }}.nginx.log:
  file.directory:
    - name: /var/log/nginx/{{ platform['basename'] }}
    - user: www-data
    - group: adm
    - mode: 0750

moodle.{{ domain }}.nginx.available:
  file.managed:
    - name: /etc/nginx/sites-available/{{ platform['basename'] }}.conf
    - source: salt://app/nginx/platform.conf.jinja
    - template: jinja
    - context:
      domain: {{ domain }}
      instance: blue
      platform: {{ platform }}
    - user: root
    - group: root
    - mode: 0644
    - require:
      - pkg: nginx
{% if pillar['systemd']['apply'] %}
    - require_in:
      - service: nginx.reload
{% endif %}

moodle.{{ domain }}.nginx.enabled:
  file.symlink:
    - name: /etc/nginx/sites-enabled/{{ platform['basename'] }}.conf
    - target: /etc/nginx/sites-available/{{ platform['basename'] }}.conf
    - require:
      - file: moodle.{{ domain }}.nginx.available
{% if pillar['systemd']['apply'] %}
    - require_in:
      - service: nginx.reload
{% endif %}

moodle.{{ domain }}.php-fpm.log:
  file.directory:
    - name: /var/log/php7.0-fpm/{{ platform['basename'] }}
    - user: {{ platform['user']['name'] }}
    - group: {{ platform['user']['name'] }}
    - mode: 0750

{% for instance in ['blue', 'green'] %}
moodle.{{ domain }}.{{ instance }}.php-fpm:
  file.managed:
    - name: /etc/php/7.0/fpm/pools-available/{{ platform['basename'] }}.{{ instance }}.conf
    - source: salt://app/php-fpm/platform.conf.jinja
    - template: jinja
    - context:
      domain: {{ domain }}
      instance: blue
      platform: {{ platform }}
    - user: root
    - group: root
    - mode: 0644
    - require:
      - pkg: php.packages
{% if pillar['systemd']['apply'] %}
    - require_in:
      - service: php-fpm.reload
{% endif %}
{% endfor %}

moodle.{{ domain }}.config:
  file.managed:
    - name: {{ platform['user']['home'] }}/config.php
    - source: salt://app/moodle/config.php.jinja
    - template: jinja
    - context:
      cfg: {{ platform['moodle'] }}
    - user: {{ platform['user']['name'] }}
    - group: {{ platform['user']['name'] }}
    - mode: 0660
{% endfor %}
