#!/bin/sh

chown -R postfix /var/spool/postfix
postconf -e "smtp_use_tls=yes"
postconf -e "smtp_tls_security_level=encrypt"

#
# Setup AWS SES sending limits

# limit to 50 messages per connection.
postconf -e "default_destination_recipient_limit=50"
# One connection to SES.
postconf -e "default_destination_concurrency_limit=1"
# Delay by 2 seconds to reconnect.
postconf -e "default_destination_rate_delay=2"
