FROM nginx:alpine

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY templates/ /etc/nginx/templates/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
