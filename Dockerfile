# FROM node:20.12 AS builder
# # FROM node:20.12-alpine3.18 AS builder
#
# COPY . ./app
# WORKDIR /app
#
# # RUN apk add --no-cache python3 make g++
# RUN yarn install && yarn build:test

FROM docker.io/golang:1.22-alpine

WORKDIR /app
# COPY ./nginx.conf /etc/nginx/conf.d/default.conf

COPY dist /app/main

