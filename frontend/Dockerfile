# Dockerfile for ENOSIS Flutter Web Application
FROM nginx:alpine

# Copy built web assets to Nginx default html directory
COPY build/web /usr/share/nginx/html

# Expose HTTP port
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
