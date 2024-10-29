FROM archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm go

WORKDIR /app
COPY main.go .
RUN go build -o godin main.go

EXPOSE 4200

ENTRYPOINT ["./godin"]
