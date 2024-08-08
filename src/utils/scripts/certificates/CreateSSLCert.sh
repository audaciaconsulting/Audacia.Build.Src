# This will create an SSL cert in the build folder called server.crt
# As well as a key called server.key
# This certificate will be based on the openssl-custom.cnf
# You can modify this if you want, but I don't see the need

openssl req \
    -newkey rsa:2048 \
    -x509 \
    -nodes \
    -keyout server.key \
    -new \
    -out server.crt \
    -config ./openssl-custom.cnf \
    -sha256 \
    -days 365