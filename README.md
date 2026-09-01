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

## 구현 상태 (Vertical Slice 리터치 완료)

유아 → 초등 → 중등 → 고등 → 입시(약 48턴)를 완주해 다중 엔딩·도감까지 도달하는 **한 판 전체가 플레이 가능**하다. Godot 4.7 프로젝트로 구현했고, 규칙·경제·진행은 엔진 독립 `core/`에 있고 밸런스·활동·이벤트·엔딩은 `data/` 리소스로 분리했다.

```
core/     엔진 독립 도메인 — 성장 공식(Growth)·밸런스(Balance)·상태머신(GameRun)·저장 직렬화
data/     데이터 리소스(JSON) — 활동 24종·이벤트·전환기·엔딩·프로필 풀
game/     Godot 조립 계층 — 화면(온보딩~엔딩~도감·상점·가챠)·컴포넌트·오토로드·모션(FX)·에셋 접합(Art)
assets/   생성 에셋 — art/(캐릭터·배경·아이콘·CG, face-blank+얼굴 앵커) · audio/(BGM 루프·스팅어·CC0 SFX)
tools/    autoplay.gd(코어 검증) · ui_harness.gd(--ui-smoke/--ui-play 드라이버) · compute_face_anchors.py
```

구현된 루프: 온보딩(아이 만들기) → 홈 → 활동 슬롯 2개 배분(+보상형 보너스 슬롯) → 결과 반응 컷(표정·델타) → 학기말 성적표 → 이벤트(일상·유대감·번아웃·유혹) → 전환기 기질 재형성(유대감 확률) → 입시 원서 → 다중 엔딩 → 도감. 결정적 성장 공식, 유혹 의존·적발, 스트레스 컨디션 계수, 확률·천장 공개 가챠, 턴 종료 자동 저장까지 포함한다.

**상용화 리터치(2026-08, DEC-033~036)**: 생성 아트 파이프라인(캐릭터 4단계×헤어 3계열 face-blank 스프라이트 + 코드 표정, 활동·홈·전환기 배경, 엔딩 CG 6종, 아이콘 세트, 코스튬·소품) · Stable Audio BGM 3루프+스팅어 4종 + Kenney CC0 UI SFX · 피드백 5단 연출(카운트업·게이지 차오름·델타 팝업 스태거·파티클·햅틱) · 가챠 리브얼(순차 공개·스킵, 압박형 금지 준수)과 코스메틱 장착(옷장·바로 입히기·테마 배경) · 화면 전환·접힘 HUD·엔딩 공유 카드 · 모바일 기본기(safe area·안드로이드 백버튼·설정 영속화 user://keeum_settings.cfg·BGM/SFX 버스·햅틱 강도). 에셋 출처는 `assets/ASSET-PROVENANCE.md`.

### 실행

```bash
# 에디터로 열기
godot --path .

# 헤드리스 완주 + 공식 검증
godot --headless --path . --script res://tools/autoplay.gd

# 실 UI 전 화면 스모크 / 한 판 완주 드라이브
godot --headless --path . -- --ui-smoke
godot --headless --path . -- --ui-play

# 실 GL 화면 캡처(시각 검수용)
godot --path . -- --ui-smoke --shots <dir>

# 안드로이드 실기기 빌드·설치 (export_presets.cfg 는 .gitignore 대상이라 아래 값으로 프리셋 생성)
godot --headless --path . --export-debug "Android" build/android/keeum.apk
adb install -r build/android/keeum.apk
```

에셋 재생성 후에는 배경 여백 트림과 얼굴 앵커 재산출을 함께 돌린다.

```bash
python3 tools/trim_bg_margins.py      # bg_*/cg_* 흰 여백 제거(엔진 cover-fit 시 흰 띠 방지)
python3 tools/compute_face_anchors.py # char_* 얼굴 앵커 재계산 → assets/art/face-anchors.json
```

### Android export 프리셋 값 (재현용)

`export_presets.cfg`는 커밋되지 않으므로 프리셋을 새로 만들 때 아래를 맞춘다.

| 항목 | 값 | 이유 |
| --- | --- | --- |
| `gradle_build/use_gradle_build` | `false` (APK) | 프리빌트 템플릿으로 실기기 검증 |
| `architectures/arm64-v8a` | `true` (나머지 false) | 실기기·마켓 타깃 |
| `package/unique_name` | `com.seorilabs.keeum` | DEC-031 |
| `screen/immersive_mode` | **`false`** | true면 safe area 인셋이 0이 되어 하단 CTA가 제스처 내비게이션과 충돌한다(실기기 확인) |
| `exclude_filter` | `assets/art/raw/*, assets/audio/raw/*, assets/art/qa_sheet.png, *-manifest.json, ASSET-PROVENANCE.md, docs/*` | 원본·문서 제외 |

밸런스 수치는 설계상 v0(Remote Config 튜닝 대상)이며, 광고·IAP·Firebase·가챠 결제는 어댑터 스텁으로 두고 코어 오프라인 플레이를 완성했다.

## 실기기 검증 (2026-08-24)

Android 16 / 1200×2670(20:9) / Mali-G615 실기기에서 디버그 APK로 전 화면을 확인했다. 120fps 안정, 크래시·스크립트 에러 없음. 실기기에서만 드러나 수정한 항목:

- immersive 모드로 인해 하단 CTA가 제스처 내비게이션과 충돌 → immersive off + safe area 인셋 적용
- `quit_on_go_back` 기본값 때문에 백버튼이 앱을 즉시 종료 → `false`로 변경, `Window.go_back_requested` 시그널 병행 연결(노티피케이션만으로는 화면 노드에 전달되지 않음)
- 종료 확인 다이얼로그가 중앙 정렬되지 않음 → `CenterContainer`로 감쌈
- 도감 2열 그리드가 좌측으로 몰림 → 셀 `SIZE_EXPAND_FILL`
- 배경 아트 위에서 캐릭터가 공중에 뜸 → `ChildAvatar.align_bottom`/`draw_scale`로 바닥선 정렬
- 생성 배경의 흰 여백이 무대에 띠로 노출 → `tools/trim_bg_margins.py`
- 설정 화면 토글·슬라이더가 엔진 기본 회색 → 게임 톤 `ToggleSwitch`/`UIKit.slider`

## 다음 게이트

1. 실기 스파이크 3건(`06-technical-production-plan.md`) — AdMob/Billing/StoreKit·Firebase 네이티브 연동, iOS export·서명.
2. 리터치 사후 검수 — BGM·스팅어 청취 QA(`assets/ASSET-PROVENANCE.md`의 afplay 목록), 저사양·타 해상도 기기 2종 추가 확인.
3. 플레이테스트 기반 밸런스 보정(유혹·전환기·페이싱)과 콘텐츠 재고 확장(활동·이벤트·엔딩, 엔딩 CG 증산 DEC-035).
