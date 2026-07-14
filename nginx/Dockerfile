FROM nginx:1.27-alpine

# Remove the default site config - we ship our own.
RUN rm -f /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/conf.d/vprofile.conf

# nginx:alpine already creates and can run as the unprivileged `nginx`
# user; the base image's entrypoint handles switching to it for the
# worker processes. Port 80 stays bindable because the container itself
# still starts as root only long enough to bind it, then drops privileges -
# this is the documented, supported behavior of the upstream image.

EXPOSE 80
