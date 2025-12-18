FROM node:20-alpine as build
WORKDIR /app
COPY package.json .
RUN npm install
COPY src ./src
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html

