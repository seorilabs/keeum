# 리서치 조사서

- 제품명: 내 새끼 대학 보내기 (app-id: keeum)
- 문서 상태: approved
- 버전/수정일: v1 / 2026-07-25
- Source of truth: 시장·경쟁작·정책·기술 리서치 원장과 검증 가설
- Open blockers: 없음 (출시 직전 재확인 항목은 본문 명시)
- 승인 근거: 사용자 최종 승인 "승인 + 승격 진행" / 2026-07-25

## 조사 범위

- 조사일: 2026-07-24 (KST). 스토어: 한국 Google Play, 한국 Apple App Store.
- 방법: 스토어 페이지·리뷰 교차 확인, KIPRIS 상표 실검색, 공식 정책·기술 문서 원문 확인, 내부 Seorilabs Godot repo 실측.
- 수치는 출처·시점을 표기하고, 출처 없는 수치는 내부 목표 또는 가설로 표시한다.

## 출처 원장

| ID | 접근일 | 유형 | 출처 |
| --- | --- | --- | --- |
| SRC-001 | 2026-07-24 | 경쟁작 | 수험생 키우기 App Store KR — https://apps.apple.com/kr/app/id6451279326 |
| SRC-002 | 2026-07-24 | 경쟁작 | 수험생 키우기 Google Play — https://play.google.com/store/apps/details?id=com.yeopcha.studentmaker |
| SRC-003 | 2026-07-24 | 경쟁작 | 한국에서 아기키우기 App Store KR — https://apps.apple.com/kr/app/id1198919809 |
| SRC-004 | 2026-07-24 | 상표 | KIPRIS 상표 검색 — https://www.kipris.or.kr |
| SRC-005 | 2026-07-24 | 정책 | 문체부 확률형 아이템 정보공개 해설서 배포 공지(2024-02-19) — https://mcst.go.kr/kor/s_notice/notice/noticeView.jsp?pSeq=17856 |
| SRC-006 | 2026-07-24 | 정책 | 김앤장 게임산업법 시행령 뉴스레터 — https://www.kimchang.com/ko/insights/detail.kc?sch_section=4&idx=28428 |
| SRC-007 | 2026-07-24 | 정책 | 화우 Legal Update 확률형 아이템 해설 — https://www.hwawoo.com/newsletter/2024_02_20/240220_k_g.pdf |
| SRC-008 | 2026-07-24 | 정책 | GRAC 등급분류 세부기준 — https://www.grac.or.kr/Institution/EtcForm01.aspx |
| SRC-009 | 2026-07-24 | 정책 | GRAC 자체등급분류 제도 — https://www.grac.or.kr/Institution/AutonomicGradePlan.aspx |
| SRC-010 | 2026-07-24 | 정책 | Apple 신규 연령등급 체계(2025-07-24) — https://developer.apple.com/news/?id=ks775ehf |
| SRC-011 | 2026-07-24 | 정책 | Apple App Store Review Guidelines 3.1.1 — https://developer.apple.com/app-store/review/guidelines/ |
| SRC-012 | 2026-07-24 | 정책 | Google Play Payments 정책(가챠 확률 공개) — https://support.google.com/googleplay/android-developer/answer/9858738 |
| SRC-013 | 2026-07-24 | 기술 | Google Play target API 요건 — https://support.google.com/googleplay/android-developer/answer/11926878 |
| SRC-014 | 2026-07-24 | 기술 | Play Billing Library 지원 일정 — https://developer.android.com/google/play/billing/deprecation-faq |
| SRC-015 | 2026-07-24 | 기술 | Godot Android export 공식 문서 — https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html |
| SRC-016 | 2026-07-24 | 기술 | Godot 릴리스(4.7.1 stable) — https://github.com/godotengine/godot/releases |
| SRC-017 | 2026-07-24 | 기술 | Poing AdMob 플러그인 v5.0.0 — https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.0.0 |
| SRC-018 | 2026-07-24 | 기술 | Godot Google Play Billing 플러그인 v3.2.0 — https://github.com/godot-sdk-integrations/godot-google-play-billing |
| SRC-019 | 2026-07-24 | 기술 | Godot StoreKit2 플러그인 v0.2 — https://github.com/godot-sdk-integrations/godot-storekit2 |
| SRC-020 | 2026-07-24 | 기술 | GodotNuts GodotFirebase v6.0.6 — https://github.com/GodotNuts/GodotFirebase |
| SRC-021 | 2026-07-24 | 기술 | Godotx Firebase 네이티브 플러그인 3.1.0 — https://github.com/godot-x/firebase |
| SRC-022 | 2026-07-24 | 기술 | GA4 Measurement Protocol 공식 한계 — https://developers.google.com/analytics/devguides/collection/protocol/ga4 |
| SRC-023 | 2026-07-24 | 기술 | Apple 제출 요건(Xcode 26) — https://developer.apple.com/news/upcoming-requirements/ |
| SRC-024 | 2026-07-24 | 정책 | AppsInToss 게임 등급분류 안내 — https://toss.im/apps-in-toss/blog/game_rating_classification |
| SRC-025 | 2026-07-24 | 기술 | Firestore REST API — https://firebase.google.com/docs/firestore/use-rest-api |

## 경쟁작 매트릭스

| 게임 | 규모 신호(출처·시점) | 코어 | 수익 | 시사점 |
| --- | --- | --- | --- | --- |
| 수험생 키우기: 수능 시뮬레이션 (Basakansoft, 2023) | App Store KR 4.8~4.9, 리뷰 약 1만, 대만 무료 1위 2025 뉴스 (SRC-001, SRC-002) | 본인(수험생) 시점 100일 시간배분 | F2P+광고+IAP | 밈성·고증 강력. 본인 시점·텍스트·디버프 피로가 약점. 우리는 부모 시점·힐링·연출로 차별 |
| Chinese Parents (Moyuwan, 2018 PC/2022 모바일) | GP 4.6 리뷰 2.1K, Steam 92% | 부모 시점 출생~고졸, 다중 직업 엔딩 | 유료 $4.99 | 부모 시점·직업 엔딩 도감·사회 풍자 검증. 냉소적·번역 불친절 → 한국화+따뜻함+매끄러운 UX |
| 한국에서 아기키우기·딸키우기 (Blue Eye) | App Store KR 4.19, 1.7만 평가 (SRC-003) | 방치형 무한 성장 B급 밈 | 광고+IAP | 세이브 손실·광고 과다·얕은 깊이가 불만. 진지한 입시 서사·안정성으로 반사이익 |
| 프린세스 메이커 모바일 계열 | 모바일 라이브 서비스 종료 | 부모 시점 딸 육성 | 종료 | 활성 모바일 육성 IP 공백 자체가 기회 |
| BitLife (인접) | 누적 1.3억 이상 | 무한 리플레이 인생 시뮬 | 광고+IAP | 다중 엔딩 리플레이의 힘. 자녀 1명 집중 육성의 감정 몰입이 우리 차별 |

## 리뷰와 플레이어 문제 종합

1. 광고 폭탄 → 보상형 중심, 강제 전면광고 최소화, 세션 8회·일 18회 이중 캡.
2. 세이브 손실·데이터 초기화 → 로컬 우선 + Firestore 백업, 스키마 마이그레이션 deterministic test.
3. 재수·세대 반복 피로 → 회차마다 다른 선천 프로필·이벤트로 콘텐츠 회전.
4. 빈약한 시각 연출 → 성장 단계별 캐릭터 변화, 감정 이벤트 컷, 엔딩 CG.
5. RNG·디버프 스트레스 → 결정적 인과 우선, 확률은 향미로만, 보상형 리롤 구제, 힐링 난이도.

## 기회와 위험

- 기회: 시장 공백 = 학부모 시점 + 힐링 무드 + 진지한 명문대 목표. 기존작은 밈 B급과 하드코어 입시로 양극화.
- 기회: 상표·스토어 선점 없음 확인(SRC-004, 2026-07-24 KIPRIS 정확 일치 0건, 양대 스토어 동명 게임 없음). 경쟁작 "수험생 키우기"는 9류 상표 등록 보유 → 마케팅 문구에 해당 명칭 표기 금지.
- 위험: 청소년이용불가 등급은 자체등급분류 대상이 아니어서 사전 심의가 필요(SRC-009). 등급 전략 A안(15세 목표)으로 회피.
- 위험: 코스메틱 가챠도 확률 공개 의무 대상(SRC-005, SRC-007). 스토어 정책은 매출 예외 없음(SRC-011, SRC-012). 2025-08-01 시행 확률 오표시 소송특례(입증책임 전환, 3배 배상).
- 위험: Apple 신규 연령등급에서 약물 참조 빈번 응답 시 18+ 산출(SRC-010) → 유혹 이벤트 노출 빈도 설계로 관리.

## 검증할 가설

| 지표 | 초기 목표 | 안정화 | 성격 |
| --- | --- | --- | --- |
| D1 | 38~42% | 45% 이상 | 캐주얼 건강 밴드 하단(가설) |
| D7 | 13~15% | 18~20% | 하이브리드 캐주얼 설계 목표(가설) |
| D30 | 6~7% | 8~10% | 장기 곡선(가설) |
| ARPDAU | $0.10~0.14 | $0.18~0.25 | 하이브리드 캐주얼 하단 시작(가설) |
| 광고:IAP | 60:40 | 55:45 | 하이브리드 전형(가설) |
| 한국 보상형 eCPM | $8~12 | 동일 | Appodeal 2024 Q4 참고치 |

검증 방법: 소프트론칭 GA4 퍼널·리텐션·수익 리포트로 가설 유지·수정·폐기 판단(07 문서 소프트론칭 게이트).

## 결정 반영

| 리서치 발견 | 반영된 결정 |
| --- | --- |
| 시장 1위가 본인 시점·하드코어 | 학부모 시점 + 힐링 톤 + 다중 엔딩 도감 (DEC-001, DEC-005) |
| 인접작 최대 불만 = 광고·세이브 | 광고 절제 UX + 저장 안정성 1급 목표 (DEC-003) |
| 실존 명칭 IP·상표 리스크 | 전면 가상 네이밍(한울대·배치동·6-A-2 로스터) (DEC-008, DEC-030) |
| 청불=자체등급분류 불가 발견 | 등급 전략 A안: 15세 수위 + 성인 마케팅 (DEC-028) |
| 코스메틱 가챠도 확률 공개 의무 | 확률·천장 공개 UI 기본 구현, 유·무상 통합 공개 (DEC-010, DEC-029) |
| Godot 스택 내부 실증 확인 | 엔진 Godot 확정, 착수 스파이크 3건 정의 (DEC-026) |

출시 직전 재확인 항목: 게임산업법 시행령 제19조의2 원문 직접 열람, 모바일 청소년이용불가 등급분류의 GCRB 이양(2026-10-01 예고) 확정 여부, 문체부 해설서 개정본 재확인.
