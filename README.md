# Oracle Cloud 무료 티어 WordPress 호스팅 가이드

Oracle Cloud Free Tier(AMD Micro)에 WordPress를 설치하는 전체 과정입니다.

## 목차

1. [사전 준비](#1-사전-준비)
2. [Oracle Cloud 인스턴스 생성](#2-oracle-cloud-인스턴스-생성)
3. [방화벽 설정 (Security List)](#3-방화벽-설정-security-list)
4. [서버 SSH 접속](#4-서버-ssh-접속)
5. [자동 설치 스크립트 실행](#5-자동-설치-스크립트-실행)
6. [수동 설정 작업](#6-수동-설정-작업)
7. [도메인 및 HTTPS 설정](#7-도메인-및-https-설정)
8. [WordPress 초기 설정](#8-wordpress-초기-설정)
9. [백업 설정 (선택)](#9-백업-설정-선택)
10. [트러블슈팅](#10-트러블슈팅)

---

## 1. 사전 준비

### 필요한 것
- Oracle Cloud 계정 (무료 가입: https://www.oracle.com/cloud/free/)
- 도메인 (가비아, Cloudflare 등에서 구매)
- SSH 키 페어

### SSH 키 생성 (없는 경우)

**macOS / Linux:**
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/oracle_key
```

**Windows (PowerShell):**
```powershell
ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\oracle_key
```

생성된 파일:
- `oracle_key` - 개인키 (접속 시 사용, 절대 공유 금지)
- `oracle_key.pub` - 공개키 (Oracle Cloud에 등록)

---

## 2. Oracle Cloud 인스턴스 생성

### 2.1 인스턴스 생성 페이지 이동
```
Oracle Cloud Console → Compute → Instances → Create Instance
```

### 2.2 설정값

| 항목 | 값 |
|------|-----|
| Name | wordpress-server |
| Compartment | (기본값) |
| Image | Ubuntu 22.04 또는 24.04 (Canonical Ubuntu) |
| Shape | VM.Standard.E2.1.Micro (1 OCPU, 1GB RAM) |
| VCN | 기존 VCN 선택 또는 새로 생성 |
| Subnet | 기존 Public Subnet 선택 |
| Public IP | Assign a public IPv4 address (체크) |
| SSH Keys | `oracle_key.pub` 내용 붙여넣기 또는 파일 업로드 |

### 2.3 생성 완료 후 확인
- **Public IP 주소** 메모 (예: 123.45.67.89)

---

## 3. 방화벽 설정 (Security List)

### 3.1 Security List 이동
```
Networking → Virtual Cloud Networks → [VCN 선택] → Security Lists → Default Security List
```

### 3.2 Ingress Rules 추가

**Add Ingress Rules** 버튼 클릭 후 아래 2개 규칙 추가:

| Source CIDR | Protocol | Port | 설명 |
|-------------|----------|------|------|
| 0.0.0.0/0 | TCP | 80 | HTTP |
| 0.0.0.0/0 | TCP | 443 | HTTPS |

---

## 4. 서버 SSH 접속

### 4.1 키 파일 권한 설정 (최초 1회)

**macOS / Linux:**
```bash
chmod 400 ~/.ssh/oracle_key
```

**Windows (PowerShell 관리자 권한):**
```powershell
icacls $env:USERPROFILE\.ssh\oracle_key /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

### 4.2 SSH 접속

**macOS / Linux:**
```bash
ssh -i ~/.ssh/oracle_key ubuntu@[PUBLIC_IP]
```

**Windows (PowerShell / CMD):**
```bash
ssh -i %USERPROFILE%\.ssh\oracle_key ubuntu@[PUBLIC_IP]
```

**예시:**
```bash
ssh -i ~/.ssh/oracle_key ubuntu@123.45.67.89
```

### 4.3 접속 확인
```
Welcome to Ubuntu 22.04.x LTS
...
ubuntu@wordpress-server:~$
```

---

## 5. 자동 설치 스크립트 실행

```bash
curl -sL https://raw.githubusercontent.com/hopaom/wordpress-oracle-hanopaler/main/wp-install.sh | sudo bash
```

### 설치 항목
스크립트가 자동으로 설치하는 것들:
- 스왑 메모리 (2GB)
- Nginx (웹서버)
- MariaDB (데이터베이스)
- PHP 8.x + 필수 확장
- WordPress 파일
- 방화벽 규칙 (iptables)
- Certbot (SSL 인증서 도구)

---

## 6. 수동 설정 작업

스크립트 완료 후 아래 작업을 순서대로 진행합니다.

### 6.1 MySQL 보안 설정

```bash
sudo mysql_secure_installation
```

| 질문 | 답변 |
|------|------|
| Enter current password for root | (그냥 Enter) |
| Switch to unix_socket authentication | N |
| Change the root password | Y → **비밀번호 입력** |
| Remove anonymous users | Y |
| Disallow root login remotely | Y |
| Remove test database | Y |
| Reload privilege tables | Y |

### 6.2 WordPress 데이터베이스 생성

```bash
sudo mysql -u root -p
```

비밀번호 입력 후:

```sql
CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'wpuser'@'localhost' IDENTIFIED BY '여기에강력한비밀번호입력';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

> ⚠️ 세미콜론을 반드시 ' 를 사용 ‘ 를 사용하면 안됨
> ⚠️ `여기에강력한비밀번호입력` 부분을 실제 비밀번호로 변경하고 기억해두세요.

### 6.3 wp-config.php 설정

```bash
cd /var/www/wordpress
sudo cp wp-config-sample.php wp-config.php
sudo nano wp-config.php
```

아래 부분을 찾아서 수정:

```php
define( 'DB_NAME', 'wordpress' );
define( 'DB_USER', 'wpuser' );
define( 'DB_PASSWORD', '위에서설정한비밀번호' );
define( 'DB_HOST', 'localhost' );
```

**보안 키 설정:**

1. 브라우저에서 https://api.wordpress.org/secret-key/1.1/salt/ 접속
2. 생성된 8줄 전체 복사
3. wp-config.php에서 기존 `AUTH_KEY`, `SECURE_AUTH_KEY` 등 8줄을 삭제하고 붙여넣기

**추가 보안 설정** (`/* That's all... */` 위에 추가):

```php
define('DISALLOW_FILE_EDIT', true);
define('WP_DEBUG', false);
```

저장: `Ctrl + O` → `Enter` → `Ctrl + X`

### 6.4 Nginx 설정

```bash
sudo nano /etc/nginx/sites-available/wordpress
```

아래 내용 붙여넣기 (도메인 부분 수정):

> ⚠️ PHP 버전 확인: `php -v` 실행 후 버전이 8.3이면 `php8.1-fpm.sock`을 `php8.3-fpm.sock`으로 변경

```nginx
server {
    listen 80;
    server_name blog.hanopaler.com;
    root /var/www/wordpress;
    index index.php index.html;

    access_log /var/log/nginx/wordpress_access.log;
    error_log /var/log/nginx/wordpress_error.log;

    client_max_body_size 64M;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\. {
        deny all;
    }

    location ~* wp-config.php {
        deny all;
    }

    location = /xmlrpc.php {
        deny all;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
```

> ⚠️ 실제 도메인으로 변경하세요.

저장 후 활성화:

```bash
sudo ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```
systemd 데몬을 리로드 경고시:

```bash
sudo systemctl daemon-reload
sudo systemctl restart nginx
```
---

## 7. 도메인 및 HTTPS 설정

### 7.1 DNS 설정

도메인 관리 페이지(가비아, Cloudflare 등)에서 A 레코드 추가:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | blog | [서버 Public IP] | 300 |

### 7.2 DNS 전파 확인

DNS 전파에 몇 분~몇 시간 소요될 수 있습니다.

```bash
# 서버에서 확인
nslookup your-domain.com
```

또는 https://dnschecker.org 에서 확인

### 7.3 SSL 인증서 발급

DNS 전파 완료 후 실행:

```bash
sudo certbot --nginx -d blog.hanopaler.com -d www.blog.hanopaler.com
```

| 질문 | 답변 |
|------|------|
| Enter email address | 이메일 입력 |
| Terms of Service | Y |
| Share email | N (선택) |
| Redirect HTTP to HTTPS | 2 (권장) |

### 7.4 자동 갱신 확인

```bash
sudo certbot renew --dry-run
```

---

## 8. WordPress 초기 설정

### 8.1 설치 마법사

브라우저에서 `https://your-domain.com` 접속

1. 언어 선택: **한국어**
2. 사이트 정보 입력:
   - 사이트 제목
   - 사용자명 (admin 말고 다른 이름 권장)
   - 비밀번호 (강력한 비밀번호)
   - 이메일
3. **WordPress 설치** 클릭

### 8.2 초기 보안 설정 (권장)

관리자 페이지 (`https://your-domain.com/wp-admin`) 접속 후:

1. **설정 → 고유주소** → "글 이름" 선택 → 저장
2. **플러그인 → 새로 추가**:
   - Wordfence Security (보안)
   - UpdraftPlus (백업)
   - WP Super Cache (캐시/속도)

---

## 9. 백업 설정 (선택)

### 자동 백업 스크립트

```bash
sudo mkdir -p /var/backups/wordpress
sudo nano /usr/local/bin/wp-backup.sh
```

```bash
#!/bin/bash
DATE=$(date +%Y%m%d)
BACKUP_DIR="/var/backups/wordpress"
DB_PASSWORD="워드프레스DB비밀번호"

# 파일 백업
tar -czf $BACKUP_DIR/files_$DATE.tar.gz /var/www/wordpress

# DB 백업
mysqldump -u wpuser -p"$DB_PASSWORD" wordpress | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# 7일 이상 된 백업 삭제
find $BACKUP_DIR -mtime +7 -delete

echo "백업 완료: $DATE"
```

```bash
sudo chmod +x /usr/local/bin/wp-backup.sh
```

### 크론잡 설정 (매일 새벽 3시 자동 실행)

```bash
sudo crontab -e
```

맨 아래에 추가:
```
0 3 * * * /usr/local/bin/wp-backup.sh
```

---

## 10. 트러블슈팅

### 사이트 접속 안 됨

```bash
# Nginx 상태 확인
sudo systemctl status nginx

# PHP-FPM 상태 확인
sudo systemctl status php8.1-fpm

# 로그 확인
sudo tail -f /var/log/nginx/wordpress_error.log
```

### 502 Bad Gateway

PHP-FPM 소켓 경로 확인:

```bash
# 실제 소켓 파일 확인
ls /var/run/php/

# Nginx 설정의 fastcgi_pass 경로와 일치하는지 확인
```

### 파일 업로드 안 됨

```bash
# PHP 업로드 설정 확인
php -i | grep upload_max_filesize

# Nginx 설정 확인
grep client_max_body_size /etc/nginx/sites-available/wordpress
```

### 메모리 부족

```bash
# 스왑 사용량 확인
free -h

# 스왑 추가 (필요시)
sudo fallocate -l 1G /swapfile2
sudo chmod 600 /swapfile2
sudo mkswap /swapfile2
sudo swapon /swapfile2
```

### SSL 인증서 갱신 실패

```bash
# 수동 갱신
sudo certbot renew

# 로그 확인
sudo cat /var/log/letsencrypt/letsencrypt.log
```

### 방화벽 확인

```bash
# iptables 규칙 확인
sudo iptables -L -n | grep -E '80|443'

# Oracle Cloud Security List 확인 (콘솔에서)
```

---

## 빠른 참조

### 주요 경로

| 항목 | 경로 |
|------|------|
| WordPress 파일 | /var/www/wordpress |
| wp-config.php | /var/www/wordpress/wp-config.php |
| Nginx 설정 | /etc/nginx/sites-available/wordpress |
| PHP 설정 | /etc/php/8.x/fpm/php.ini |
| Nginx 로그 | /var/log/nginx/ |
| 백업 폴더 | /var/backups/wordpress |

### 주요 명령어

```bash
# 서비스 재시작
sudo systemctl restart nginx
sudo systemctl restart php8.1-fpm
sudo systemctl restart mariadb

# 서비스 상태 확인
sudo systemctl status nginx
sudo systemctl status php8.1-fpm
sudo systemctl status mariadb

# 로그 실시간 확인
sudo tail -f /var/log/nginx/wordpress_error.log

# 디스크 사용량
df -h

# 메모리 사용량
free -h
```

---

## 라이선스

MIT License
