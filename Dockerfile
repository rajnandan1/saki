FROM nginx:alpine

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY templates/ /etc/nginx/templates/

# Route prefixes — change these to any random path to bypass adblockers
ENV ROUTE_GTM=tg
ENV ROUTE_GA=an
ENV ROUTE_AMP_CDN=acdn
ENV ROUTE_AMP_API=aapi
ENV ROUTE_MIX_CDN=mxc
ENV ROUTE_MIX_API=mxa
ENV ROUTE_CLARITY=cla
ENV ROUTE_PH_JS=phj
ENV ROUTE_PH_API=pha

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
