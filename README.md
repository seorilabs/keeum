# 내 새끼 대학 보내기 (keeum)

학부모가 되어 유아기부터 고3까지 자녀의 월간 활동을 배분해, 성적·정서·체력·특기·유대감의 균형을 지키며 명문대(가상 한울대)와 다양한 인생 엔딩으로 키워내는 **한국 교육열 풍자 힐링 육성 시뮬레이션**.

| 항목 | 값 |
| --- | --- |
| 상태 | 기획 승인 완료(2026-07-25), Core Gate 착수 전 |
| 스택 | Godot + Firebase (Clean Architecture) |
| 출시 타깃 | Google Play · Apple App Store (AppsInToss는 phase 2 후보) |
| package / bundle | `com.seorilabs.keeum` |
| 시장 | 한국 단독 |
| 등급 전략 | 실제 등급 15세 목표 + 성인 타깃 마케팅 |

## 문서

설계 원장은 `docs/game-design/`이다.

- `00-product-brief.md` — 제품 계약·범위·성공 기준
- `01-research-dossier.md` — 시장·정책·기술 리서치 원장
- `02-gdd.md` — 코어 루프·규칙·밸런스 공식·인수 시나리오
- `03-ui-ux-spec.md` — 화면 계약·상태·피드백·온보딩 스토리보드
- `04-art-audio-bible.md` — 아트 방향·에셋 매니페스트·오디오 이벤트 맵
- `05-economy-content-liveops.md` — 재화·가격·가챠·콘텐츠·라이브옵스
- `06-technical-production-plan.md` — 아키텍처·플랫폼 연동·제작 게이트
- `07-qa-launch-plan.md` — QA·정책 게이트·소프트론칭·롤백
- `decision-log.md` — 의사결정 원장(DEC-###)

기획 원본: Obsidian `프로젝트/개인/keeum/01 기획서`.

## 다음 게이트

1. Core Gate 진입 조건: 실기 스파이크 3건(`06-technical-production-plan.md` 플랫폼 연동 절 참조).
2. 저장·로드 + 활동→스탯→학기 최소 루프 + 성장 공식 deterministic test.
3. Vertical Slice 전 style anchor·대표 화면 high-fidelity target 승인.
