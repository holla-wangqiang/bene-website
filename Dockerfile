# 第一阶段：构建阶段
FROM docker.io/node:20.12 as builder

WORKDIR /app

# 复制 package.json 和 yarn.lock 并安装依赖
COPY package.json yarn.lock ./
RUN yarn install --registry https://registry.npmjs.org/

# 复制源代码并构建
COPY . .
RUN yarn build

# 第二阶段：部署阶段
FROM nginx:stable-alpine

COPY --from=builder /app/dist /usr/share/nginx/html
# COPY ./nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
