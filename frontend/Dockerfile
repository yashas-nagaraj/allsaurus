FROM nginx:alpine

# 1. Remove the default Nginx config
RUN rm /etc/nginx/conf.d/default.conf

# 2. Copy our NEW custom config (the one you just made)
COPY default.conf /etc/nginx/conf.d/

# 3. Copy the website files
COPY . /usr/share/nginx/html
