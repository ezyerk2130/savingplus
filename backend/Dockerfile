FROM golang:1.22-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /savingplus-api ./cmd/api/

FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=builder /savingplus-api .
COPY --from=builder /app/migrations ./migrations/

EXPOSE 8080 8081

CMD ["./savingplus-api"]
