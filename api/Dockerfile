FROM ruby:3.4.3-slim

# Install dependencies required for PostgreSQL and other gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    libpq-dev \
    postgresql-client \
    pkg-config \
    libyaml-dev \
    git \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Set working directory
WORKDIR /app

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy the application code
COPY . .

# Add a script to be executed every time the container starts
COPY bin/docker-entrypoint /usr/bin/
RUN chmod +x /usr/bin/docker-entrypoint

EXPOSE 3000

# Configure the main process to run when running the image
ENTRYPOINT ["docker-entrypoint"]
CMD ["rails", "server", "-b", "0.0.0.0"]