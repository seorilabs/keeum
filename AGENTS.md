# keeum Agent Instructions

## 기본 원칙

- 한글을 주 사용언어로 한다.
- 항상 간결하고 실무적으로 답변한다.
- 애매한 부분은 상상해서 채우지 말고 파일, 로그, 설정, 실행 결과를 먼저 확인한다.
- 복잡한 구조 설명은 가능하면 Mermaid로 도식화한다.

## Source Of Truth

- 기획·의사결정·마켓·릴리스 준비 상태의 원장은 `docs/game-design/`이다. 기획 원본은 Obsidian `프로젝트/개인/keeum/01 기획서`.
- 승인된 결정을 뒤집는 변경은 `docs/game-design/decision-log.md`에 새 DEC 항목으로 추가하고 사용자 확인을 받는다.
- 확정 값: 제품명 "내 새끼 대학 보내기", package/bundle `com.seorilabs.keeum`, 가격·가챠 수치(05 문서), 가상 네이밍(한울대·배치동·기관 14슬롯·강사 6종). 임의 변경 금지.

## 콘텐츠 가드레일 (등급 전략 A안)

- 실제 등급 15세 목표. 약물·편법(유혹 시스템) 묘사는 투약 행위·효과의 구체 연출 없이 선택·결과 중심 간접 표현으로 고정한다.
- 실존 대학·학원·강사·약품명 사용 금지(전면 가상 네이밍 + 허구 면책 고지).
- 가챠는 코스메틱 한정. 확률·천장 공개 UI와 무료 획득 경로를 유지하고, 표기 확률과 추첨 로직 일치를 deterministic test로 보증한다.
- 감정 순간(가족 컷·전환기·엔딩)에 광고·상점을 노출하지 않는다.

## 구조 원칙

- 게임 도메인(규칙·경제·진행)은 엔진 독립 core로 분리하고, Godot·Firebase·광고·결제 SDK는 어댑터에서만 import한다.
- 밸런스 상수·활동·이벤트·엔딩은 데이터 리소스로 분리해 Remote Config로 튜닝 가능하게 한다.
- GDScript strict typing을 강제하고, PR마다 Godot compile-only 게이트를 통과시킨다.

## CI·러너

- lint·경량 검증: `runs-on: seorilabs-rpi-arm64`. Android AAB release: x64 Linux. Apple archive: macOS. 두 release 작업을 RPI ARM64로 보내지 않는다.
- 설계 팩 구조 검증: `python3 ~/.claude/skills/game-planning-production/scripts/validate_design_pack.py docs/game-design --strict`.

## 승인 게이트

- 대량 아트·사운드 생성 전에 style anchor·대표 화면 target을 사용자 승인으로 고정한다(유료 생성 API 임의 호출 금지).
- 스토어 제출·프로덕션 배포는 별도 deployment approval 전에는 하지 않는다.
