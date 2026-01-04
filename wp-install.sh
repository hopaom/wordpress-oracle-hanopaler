#!/bin/bash

# ============================================
# WordPress 자동 설치 스크립트
# Oracle Cloud AMD Micro (Ubuntu 22.04/24.04)
# GitHub: https://github.com/USERNAME/oracle-wordpress
# ============================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_step() {
    echo ""
    echo -e "${GREEN}==== $1 ====${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

# Root 권한 확인
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}sudo로 실행해주세요: sudo bash wp-install.sh${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  WordPress 자동 설치 시작${NC}"
echo -e "${GREEN}  Oracle Cloud Free Tier (AMD Micro)${NC}"
echo -e "${GREEN}============================================${NC}"

# ============================================
# 1. 스왑 메모리 설정
# ============================================
print_step "1/8 스왑 메모리 설정 (2GB)"
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo "✓ 스왑 설정 완료"
else
    echo "→ 스왑 이미 존재함, 스킵"
fi
free -h

# ============================================
# 2. 시스템 업데이트
# ============================================
print_step "2/8 시스템 업데이트"
apt update && apt upgrade -y
echo "✓ 시스템 업데이트 완료"

# ============================================
# 3. Nginx 설치
# ============================================
print_step "3/8 Nginx 설치"
apt install -y nginx
systemctl enable nginx
systemctl start nginx
echo "✓ Nginx 설치 완료"

# ============================================
# 4. MariaDB 설치
# ============================================
print_step "4/8 MariaDB 설치"
apt install -y mariadb-server mariadb-client
systemctl enable mariadb
systemctl start mariadb
echo "✓ MariaDB 설치 완료"

# ============================================
# 5. PHP 설치
# ============================================
print_step "5/8 PHP 설치"
apt install -y php-fpm php-mysql php-curl php-gd php-intl \
    php-mbstring php-soap php-xml php-xmlrpc php-zip php-imagick

# PHP 버전 감지 및 설정 최적화
PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
PHP_INI="/etc/php/${PHP_VERSION}/fpm/php.ini"

sed -i 's/upload_max_filesize = .*/upload_max_filesize = 64M/' $PHP_INI
sed -i 's/post_max_size = .*/post_max_size = 64M/' $PHP_INI
sed -i 's/max_execution_time = .*/max_execution_time = 300/' $PHP_INI
sed -i 's/memory_limit = .*/memory_limit = 128M/' $PHP_INI
systemctl restart php${PHP_VERSION}-fpm

echo "✓ PHP ${PHP_VERSION} 설치 완료"

# ============================================
# 6. WordPress 다운로드
# ============================================
print_step "6/8 WordPress 다운로드"
cd /var/www
if [ ! -d "wordpress" ]; then
    wget -q --show-progress https://wordpress.org/latest.tar.gz
    tar -xzf latest.tar.gz
    rm latest.tar.gz
    chown -R www-data:www-data /var/www/wordpress
    chmod -R 755 /var/www/wordpress
    echo "✓ WordPress 다운로드 완료"
else
    echo "→ WordPress 폴더 이미 존재함, 스킵"
fi

# ============================================
# 7. 방화벽 설정
# ============================================
print_step "7/8 방화벽 설정 (80, 443 포트)"
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 80 -j ACCEPT
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 443 -j ACCEPT
netfilter-persistent save
echo "✓ 방화벽 설정 완료"

# ============================================
# 8. Certbot 설치
# ============================================
print_step "8/8 Certbot 설치"
apt install -y certbot python3-certbot-nginx
echo "✓ Certbot 설치 완료"

# ============================================
# 설치 완료 메시지
# ============================================
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}    자동 설치 완료!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}[남은 수동 작업 - 순서대로 진행하세요]${NC}"
echo ""
echo "─────────────────────────────────────────────"
echo -e "${GREEN}1. MySQL 보안 설정${NC}"
echo "─────────────────────────────────────────────"
echo "sudo mysql_secure_installation"
echo ""
echo "  → Enter current password for root: [그냥 Enter]"
echo "  → Switch to unix_socket authentication: N"
echo "  → Change the root password: Y → 비밀번호 입력"
echo "  → Remove anonymous users: Y"
echo "  → Disallow root login remotely: Y"
echo "  → Remove test database: Y"
echo "  → Reload privilege tables: Y"
echo ""
echo "─────────────────────────────────────────────"
echo -e "${GREEN}2. WordPress 데이터베이스 생성${NC}"
echo "─────────────────────────────────────────────"
echo "sudo mysql -u root -p"
echo ""
echo "  CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
echo "  CREATE USER 'wpuser'@'localhost' IDENTIFIED BY '여기에비밀번호입력';"
echo "  GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';"
echo "  FLUSH PRIVILEGES;"
echo "  EXIT;"
echo ""
echo "─────────────────────────────────────────────"
echo -e "${GREEN}3. wp-config.php 설정${NC}"
echo "─────────────────────────────────────────────"
echo "cd /var/www/wordpress"
echo "sudo cp wp-config-sample.php wp-config.php"
echo "sudo nano wp-config.php"
echo ""
echo "  → DB_NAME: 'wordpress'"
echo "  → DB_USER: 'wpuser'"
echo "  → DB_PASSWORD: '위에서 설정한 비밀번호'"
echo "  → 보안키 생성: https://api.wordpress.org/secret-key/1.1/salt/"
echo ""
echo "─────────────────────────────────────────────"
echo -e "${GREEN}4. Nginx 설정${NC}"
echo "─────────────────────────────────────────────"
echo "sudo nano /etc/nginx/sites-available/wordpress"
echo "(README.md의 Nginx 설정 내용 붙여넣기)"
echo ""
echo "sudo ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/"
echo "sudo rm /etc/nginx/sites-enabled/default"
echo "sudo nginx -t && sudo systemctl restart nginx"
echo ""
echo "─────────────────────────────────────────────"
echo -e "${GREEN}5. 도메인 DNS 설정${NC}"
echo "─────────────────────────────────────────────"
echo "도메인 관리 페이지에서 A 레코드 추가:"
echo "  → @: $(curl -s ifconfig.me)"
echo "  → www: $(curl -s ifconfig.me)"
echo ""
echo "─────────────────────────────────────────────"
echo -e "${GREEN}6. SSL 인증서 발급 (DNS 전파 후)${NC}"
echo "─────────────────────────────────────────────"
echo "sudo certbot --nginx -d your-domain.com -d www.your-domain.com"
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  설치 가이드: README.md 참고${NC}"
echo -e "${GREEN}============================================${NC}"
