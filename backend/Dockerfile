FROM golang:1.23-alpine AS builder

RUN apk add --no-cache git ca-certificates

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /savingplus-api ./cmd/api/
RUN CGO_ENABLED=0 GOOS=linux go build -o /savingplus-seed ./cmd/seedadmin/

FROM alpine:3.19

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app

COPY --from=builder /savingplus-api .
COPY --from=builder /savingplus-seed .
COPY --from=builder /app/migrations ./migrations/

EXPOSE 8080

CMD ["./savingplus-api"]
