#!/bin/bash

# script is updated with the template_file variables (check main.tf)
# the script not includes some HTML syntax to make the output 
# a bit more readable in a web browser
cat > index.html <<EOF
<h1>Hello, World</h1>
<p>DB address: ${db_address}</p>
<p>DB port: ${db_port}</p>
EOF

nohup busybox httpd -f -p ${server_port} &