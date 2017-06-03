#
# Ubiquitous Moodle
#
# @author Luke Carrier <luke@carrier.im>
# @copyright 2016 Luke Carrier
#

include:
  - base
  - selenium-base

x11vnc:
  pkg.installed:
    - pkgs:
      - x11vnc
      - xvfb

{% if pillar['systemd']['apply'] %}
x11vnc.service:
  service.running:
    - enable: True
    - reload: True
    - require:
      - file: /etc/systemd/system/x11vnc.service
      - file: /etc/systemd/system/xvfb.service
{% endif %}

x11vnc.fonts:
  pkg.installed:
    - pkgs:
      - fonts-liberation
      - ttf-ubuntu-font-family

/etc/systemd/system/selenium-node.service:
  file.managed:
    - source: salt://selenium-node-base/systemd/selenium-node.service
    - user: root
    - group: root
    - mode: 0644

/etc/systemd/system/xvfb.service:
  file.managed:
    - source: salt://selenium-node-base/systemd/xvfb.service
    - user: root
    - group: root
    - mode: 0644

/etc/systemd/system/x11vnc.service:
  file.managed:
    - source: salt://selenium-node-base/systemd/x11vnc.service
    - user: root
    - group: root
    - mode: 0644

{% if pillar['systemd']['apply'] %}
selenium-node:
  service.running:
    - enable: True
    - reload: True
    - require:
      - file: /etc/systemd/system/selenium-node.service
      - file: /etc/systemd/system/xvfb.service
      - file: /opt/selenium/selenium-server.jar
      - pkg: oracle-java.java8
      - pkg: x11vnc
{% endif %}
