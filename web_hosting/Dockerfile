# Serves the Submersion web bundle with nginx. Build from inside the
# unpacked bundle folder, where this file sits beside index.html:
#
#   docker build -t submersion-web .
#   docker run --rm -p 8080:80 submersion-web
#
# then open http://localhost:8080. Anywhere but your own machine, put a
# TLS-terminating proxy in front: the app needs HTTPS (or localhost).
# See HOSTING.md.
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY . /usr/share/nginx/html
