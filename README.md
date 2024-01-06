# A simple firewall that blocks IP addresses with iptables, that potentially try to break into the server using http/https 

The script should be run in cron.
Checks the Apache log file every specified time and tries to detect IP addresses that scan the website and try to hack into the server

