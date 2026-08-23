FROM ruby:4.0.2

ARG GECKODRIVER_VERSION=0.37.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends firefox-esr xauth xvfb \
    && curl -fsSL \
      "https://github.com/mozilla/geckodriver/releases/download/v${GECKODRIVER_VERSION}/geckodriver-v${GECKODRIVER_VERSION}-linux64.tar.gz" \
      | tar -xz -C /usr/local/bin \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 2.4.19 --no-document \
    && bundle _2.4.19_ install

COPY . .

RUN find . -type f \
      \( -name '*.rb' -o -name '*.rake' -o -name '*.sh' -o -name Gemfile \
      -o -name Rakefile -o -name Guardfile -o -name config.ru \
      -o -name docker-test \) \
      -exec sed -i 's/\r$//' {} + \
    && chmod +x script/docker-test

ENV NEW_RELIC_AGENT_ENABLED=false \
    PORT=5000 \
    RACK_ENV=development

EXPOSE 5000

CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:5000"]
