include:
  - base

iptables.persistent:
  pkg.installed:
    - pkgs:
      - iptables-persistent

{% for rule in salt['pillar.get']('iptables:rules', []) %}
iptables.rules.{{ loop.index }}:
  iptables.insert:
{% for pair in rule %}
    - {{ pair.keys()[0] }}: {{ pair.values()[0] | yaml }}
{% endfor %}
    - save: True
    - require:
      - iptables: iptables.default.input.established
    - require_in:
      - iptables: iptables.default.input.drop
{% endfor %}
