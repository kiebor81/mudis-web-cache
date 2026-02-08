FROM ruby:3.3-slim

ENV APP_HOME=/app
WORKDIR $APP_HOME

RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential \
  && rm -rf /var/lib/apt/lists/*

COPY mudis-web-cache/ mudis-web-cache/

WORKDIR $APP_HOME/mudis-web-cache

RUN bundle install \
  && chmod +x ./bin/mudis

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
