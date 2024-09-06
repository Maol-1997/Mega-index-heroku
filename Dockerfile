FROM ubuntu:latest
ARG DEBIAN_FRONTEND=noninteractive
RUN DEBIAN_FRONTEND=noninteractive
RUN apt update -y
RUN apt install unzip curl wget git expect -y
RUN curl https://cli-assets.heroku.com/install.sh | sh
RUN git clone https://github.com/Maol-1997/Mega-index-heroku; chmod +x /Mega-index-heroku/entrypoint.sh
CMD /Mega-index-heroku/entrypoint.sh
