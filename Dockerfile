##############################################################################
# meteor-dev stage - builds image for dev and used with docker-compose.yml
##############################################################################
FROM reactioncommerce/base:v4.0.2 as meteor-dev

LABEL maintainer="Reaction Commerce <architecture@reactioncommerce.com>"

ENV PATH $PATH:/home/node/.meteor

COPY package-lock.json $APP_SOURCE_DIR/
RUN sudo chown -R node $APP_SOURCE_DIR/
COPY package.json $APP_SOURCE_DIR/
RUN sudo chown -R node $APP_SOURCE_DIR/

# Because Docker Compose uses a named volume for node_modules and named volumes are owned
# by root by default, we have to initially create node_modules here with correct owner.
# Without this NPM cannot write packages into node_modules later, when running in a container.
RUN mkdir "$APP_SOURCE_DIR/node_modules" && chown node "$APP_SOURCE_DIR/node_modules"

RUN meteor npm install

COPY . $APP_SOURCE_DIR
RUN sudo chown -R node $APP_SOURCE_DIR

##############################################################################
# builder stage - builds the production bundle
##############################################################################
FROM meteor-dev as builder

RUN printf "\\n[-] Running Reaction plugin loader...\\n" \
 && reaction plugins load
RUN printf "\\n[-] Building Meteor application...\\n" \
 && meteor build --server-only --architecture os.linux.x86_64 --directory "$APP_BUNDLE_DIR"

WORKDIR $APP_BUNDLE_DIR/bundle/programs/server/

RUN meteor npm install --production


##############################################################################
# final build stage - create the final production image
##############################################################################
FROM node:8.9.4-slim

# Default environment variables

# grab the dependencies and built app from the previous builder image
COPY --from=builder /opt/reactin/dist/bundle /app
RUN sudo chown -r node /app

WORKDIR /app

EXPOSE 3000

CMD ["node", "main.js"]

RUN ["chmod", "+x", "/app/run.sh"]

CMD ["/app/run.sh"]