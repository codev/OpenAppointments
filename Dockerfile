# Cloudron package image. Both stages use cloudron/base so the Ruby build links against
# the same system libraries as the runtime. Ruby is installed with mise, matching the
# project toolchain (mise.toml pins the version).
FROM cloudron/base:5.0.0 AS builder

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git curl pkg-config \
        libssl-dev libyaml-dev zlib1g-dev libsqlite3-dev && \
    rm -rf /var/lib/apt/lists/*

ENV MISE_DATA_DIR=/opt/mise MISE_CONFIG_DIR=/opt/mise-config PATH=/opt/mise/shims:/root/.local/bin:$PATH
RUN curl -fsSL https://mise.run | sh

WORKDIR /app/code
COPY mise.toml Gemfile Gemfile.lock ./
RUN mise install && mise reshim

RUN bundle config set --local deployment true && \
    bundle config set --local without "development test" && \
    bundle install --jobs 4

COPY . .
RUN SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bundle exec rails assets:precompile

FROM cloudron/base:5.0.0

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libsqlite3-0 libyaml-0-2 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/mise /opt/mise
COPY --from=builder /app/code /app/code

WORKDIR /app/code

# mise-installed Ruby used directly via its version alias (no shims; mise binary not shipped).
ENV PATH=/opt/mise/installs/ruby/3.4/bin:$PATH \
    RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_DB_DIR=/app/data/db \
    RAILS_STORAGE_DIR=/app/data/storage \
    SOLID_QUEUE_IN_PUMA=true \
    BUNDLE_DEPLOYMENT=true \
    BUNDLE_WITHOUT="development test"

RUN chmod +x /app/code/start.sh && \
    rm -rf /app/code/storage && ln -s /app/data/storage /app/code/storage && \
    rm -rf /app/code/tmp && ln -s /run/app-tmp /app/code/tmp && \
    rm -rf /app/code/log && ln -s /run/app-log /app/code/log

CMD ["/app/code/start.sh"]
