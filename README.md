# ДЗ 1. Фундамент DevOps-инфраструктуры

Инфраструктура для веб-приложения на одной VM (Ubuntu 24.04, `111.88.162.133`).

| Компонент | Инструмент | Результат |
|---|---|---|
| Настройка хоста | Ansible (`setup_host.yml`) | пользователь `deployer`, Docker + Compose v2, вход по SSH только по ключу |
| Приложение | Ansible (`deploy_app.yml`) + Docker Compose | nginx reverse proxy → app, порт 80 |
| Отдельный сервис | Terraform + провайдер `kreuzwerker/docker` | статическая страница в своей сети, порт 8081 |
| Мониторинг | `scripts/monitor.sh` | статус сервиса, журнал, ошибки в syslog за час |

```
                  ┌─────────────────────── VM 111.88.162.133 ───────────────────────┐
 браузер ──:80──▶ │ hw1-proxy (nginx) ──hw1_backend (internal)──▶ hw1-app (nginx)   │  Ansible + Compose
 браузер ─:8081─▶ │ tf-web (nginx), сеть tf-web-net 172.30.0.0/24                   │  Terraform
                  └─────────────────────────────────────────────────────────────────┘
```

## Структура репозитория

```
ansible/      ansible.cfg, inventory.ini, group_vars/all.yml
              setup_host.yml, deploy_app.yml
              roles/users, roles/docker, roles/ssh_hardening, roles/app
compose/      docker-compose.yml, proxy/nginx.conf, app/index.html
terraform/    versions.tf, variables.tf, main.tf, outputs.tf
              modules/web, templates/index.html.tftpl
scripts/      monitor.sh
```

## Требования

На управляющей машине (WSL Ubuntu):

- Ansible ≥ 2.16
- Terraform ≥ 1.6
- SSH-ключ `~/.ssh/id_ed25519`, публичная часть добавлена пользователю `student` на VM

На VM: Ubuntu 20.04+, Python 3, пользователь `student` с `sudo` без пароля и в группе `docker`.

## Запуск

### 1. Настройка хоста

```bash
cd ansible
ansible app -m ping
ansible-playbook setup_host.yml
```

### 2. Деплой приложения

```bash
ansible-playbook deploy_app.yml
curl -i http://111.88.162.133/
```

### 3. Terraform

Реестр HashiCorp недоступен из РФ, поэтому провайдеры устанавливаются с зеркала Яндекса. Файл `~/.terraformrc`:

```hcl
provider_installation {
  network_mirror {
    url     = "https://terraform-mirror.yandexcloud.net/"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
```

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
curl -i http://111.88.162.133:8081/
```

Удаление: `terraform destroy`.

### 4. Мониторинг

```bash
scp scripts/monitor.sh student@111.88.162.133:
ssh student@111.88.162.133 'sudo ./monitor.sh docker'
ssh student@111.88.162.133 'sudo ./monitor.sh nginx 5'
```

Использование: `./monitor.sh <service> [lines]`, по умолчанию выводится 10 строк журнала.

| Код выхода | Значение |
|---|---|
| 0 | сервис active |
| 1 | сервис не active |
| 2 | ошибка аргументов |
| 3 | сервис не найден |
| 4 | нет нужных утилит |

## Результаты

### Идемпотентность Ansible

`setup_host.yml`: первый прогон после добавления роли `ssh_hardening` и повторный прогон.

```
vm1 : ok=11  changed=2  unreachable=0  failed=0  skipped=0  rescued=0  ignored=0
vm1 : ok=9   changed=0  unreachable=0  failed=0  skipped=0  rescued=0  ignored=0
```

`deploy_app.yml`, повторный прогон:

```
vm1 : ok=6   changed=0  unreachable=0  failed=0  skipped=0  rescued=0  ignored=0
```

### Пользователь deployer

```
$ ssh deployer@111.88.162.133 'whoami; groups; sudo whoami'
deployer
deployer docker
root
```

### SSH только по ключу

```
$ ssh -o PubkeyAuthentication=no -o PreferredAuthentications=password student@111.88.162.133
student@111.88.162.133: Permission denied (publickey).
```

### Reverse proxy

```
$ curl -i http://111.88.162.133/
HTTP/1.1 200 OK
Server: nginx
X-Served-By: proxy

<h1>Hello World</h1>
```

### Terraform

```
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:
container = "tf-web"
network   = "tf-web-net"
url       = "http://111.88.162.133:8081/"

$ terraform plan
No changes. Your infrastructure matches the configuration.
```

```
$ curl -i http://111.88.162.133:8081/
HTTP/1.1 200 OK

<h1>Hello from Terraform</h1>
<p>Container: tf-web, network: tf-web-net (172.30.0.0/24), port: 8081</p>
```

### monitor.sh

```
$ sudo ./monitor.sh docker
Service docker: active
Errors in /var/log/syslog for the last hour: 77

$ sudo ./monitor.sh nginx 5
Service nginx: inactive
--- last 5 journal lines ---
Oct 14 15:07:44 shilnikovad systemd[1]: nginx.service: Deactivated successfully.
Oct 14 15:07:44 shilnikovad systemd[1]: Stopped nginx.service - A high performance web server and a reverse proxy server.
Errors in /var/log/syslog for the last hour: 77

$ sudo ./monitor.sh nosuchservice
ERROR: service 'nosuchservice' not found       (exit 3)

$ ./monitor.sh
Usage: ./monitor.sh <service> [lines]          (exit 2)
```
