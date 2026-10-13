FROM node:24.21.0-bookworm-slim AS assemble
WORKDIR /source
COPY . .
RUN node server/assemble_runtime.mjs /source /runtime

FROM node:24.21.0-bookworm-slim
ARG TARGETARCH
ARG GODOT_URL=https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
ARG GODOT_SHA256=cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4
RUN test "$TARGETARCH" = amd64
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 libwayland-client0 libwayland-cursor0 libwayland-egl1 libasound2 && rm -rf /var/lib/apt/lists/*
RUN test -n "$GODOT_URL" && test -n "$GODOT_SHA256" && curl -fsSL "$GODOT_URL" -o /tmp/godot.zip && printf '%s  /tmp/godot.zip\n' "$GODOT_SHA256" | sha256sum -c - && unzip /tmp/godot.zip -d /tmp/godot && install -m755 /tmp/godot/Godot*_linux.x86_64 /usr/local/bin/godot && rm -rf /tmp/godot /tmp/godot.zip
WORKDIR /app
COPY --from=assemble /runtime/ ./
WORKDIR /app/server
RUN npm ci --omit=dev --ignore-scripts
WORKDIR /app
RUN mkdir -p /data && chown node:node /data /app
USER node
ENV ENDLESS_HOST=0.0.0.0 ENDLESS_PORT=8080 ENDLESS_DB=/data/world.sqlite GODOT_BINARY=/usr/local/bin/godot PUBLIC_WORLD=1
EXPOSE 8080
CMD ["node", "server/index.mjs"]
