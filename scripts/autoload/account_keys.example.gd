# 구글 계정 연동용 OAuth 클라이언트 값 예시. 같은 폴더에 account_keys.gd 로 복사해 값을 채운다 (커밋하지 않음).
# 값은 Google Cloud 콘솔 > company-defense > API 및 서비스 > 사용자 인증 정보에 있다.
# 웹 배포는 GitHub Actions 가 저장소 시크릿(WEB_CLIENT_ID, DEVICE_CLIENT_ID, DEVICE_CLIENT_SECRET)으로 이 파일을 만든다.
extends RefCounted

const WEB_CLIENT_ID := ""         # 웹 애플리케이션 클라이언트 ID (웹 로그인)
const DEVICE_CLIENT_ID := ""      # TV 및 입력 제한 기기 클라이언트 ID (안드로이드, PC 로그인)
const DEVICE_CLIENT_SECRET := ""  # 위 클라이언트의 보안 비밀번호
