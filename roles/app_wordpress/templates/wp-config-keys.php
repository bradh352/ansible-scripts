<?php
{% set keyArray = [ 'AUTH_KEY', 'SECURE_AUTH_KEY', 'LOGGED_IN_KEY', 'NONCE_KEY', 'AUTH_SALT', 'SECURE_AUTH_SALT', 'LOGGED_IN_SALT', 'NONCE_SALT' ] %}
{% for key in keyArray %}
{%   set charset='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789`~!@#$%^&*()-_=+{}[]|;:<>,./?' %}
{%   set randkey=[] %}
{%   for i in range(64) %}
{%     do randkey.append(charset|random) %}
{%   endfor %}
define('{{ key }}', '{{ randkey|join('') }}');
{% endfor %}
