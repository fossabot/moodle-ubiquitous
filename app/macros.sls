{%- macro lane_location(platform, lane) %}
    location ~ {{ lane['location'] | replace('\\\\', '\\') }} {
        if ($platform_maintenance != 0) {
            return 503;
        }

{% for condition in lane.get('conditions', {}) %}
        if ({{ condition['condition'] }}) {
{%- for variable, value in condition.get('variables', {}).items() %}
            set ${{ variable }} {{ value }};
{%- endfor %}
        }
{% endfor %}

{%- if 'fastcgi_read_timeout' in lane %}
        fastcgi_read_timeout {{ lane['fastcgi_read_timeout'] }};
{%- endif %}

        include snippets/fastcgi-php.conf;
        fastcgi_param SCRIPT_FILENAME $document_root$1;
{%- for parameter, value in lane.get('fastcgi_params', {}).items() %}
        fastcgi_param {{ parameter }} {{ value | json | replace('\\\\n', '\n') }};
{%- endfor %}
        fastcgi_pass unix:/var/run/php/php7.0-fpm-{{ platform['basename'] }}.sock;
    }
{%- endmacro %}
