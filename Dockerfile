FROM perl:5
RUN apt-get update
RUN apt-get -y install libmagic-dev
RUN cpanm Carton
RUN mkdir /app
WORKDIR /app
COPY cpanfile* /app
RUN carton install
COPY . /app
CMD ["carton", "exec", "perl", "-I", ".", "gin.pl"]
