# 에셋 출처·라이선스 원장

04-art-audio-bible 규정: 생성물·외부 자산의 출처/모델/프롬프트/라이선스/수정 이력/마켓 사용 가능성 추적.
프롬프트 원본은 `art/asset-manifest.json`, `audio/sound-manifest.json` 이 원장이다(파일별 중복 기재 생략).

## 생성 이미지 (assets/art/)

| 대상 | 출처/모델 | 프롬프트 | 라이선스 | 수정 이력 | 마켓 사용 |
| --- | --- | --- | --- | --- | --- |
| `style/anchor.jpg` + `char_*` `cos_*` `icon_*` `act_*` `bg_*` `cg_*` `pet_*` `acc_*` `deco_*` `app_icon` `splash` 전체 | Google Gemini API `gemini-3-pro-image` (앵커 탐색만 `gemini-2.5-flash-image` draft, 산출물 미사용) | `art/asset-manifest.json` 의 각 항목 + `art/style/style-guide.md` | Gemini API 생성물 — 서비스 약관상 상업적 사용 가능, 소유권 사용자 귀속 | rembg 배경 제거 + 알파 트림 + 캔버스 정규화(스킬 파이프라인), 배경류는 cover-crop | 가능 |
| `art/face-anchors.json` | 자체 산출(`tools/compute_face_anchors.py`) | — | 프로젝트 자산 | 스프라이트별 얼굴 앵커 자동 계산 | 가능 |

- 스타일 앵커 승인: DEC-033(일괄 자율 진행)에 따라 에이전트 자체 QA 체크리스트로 고정(2026-08-23),
  draft 3안 탐색 → C안 채택 → pro 모델 재생성. 사후 검수 대상.
- 실존 명칭 검색: DEC-036 (한울대·배치동·나수리·도지문 무충돌 확인, 서라벌대→누리대 교체).

## 생성 오디오 (assets/audio/)

| 대상 | 출처/모델 | 프롬프트 | 라이선스 | 수정 이력 | 마켓 사용 |
| --- | --- | --- | --- | --- | --- |
| `bgm_home.ogg` `bgm_transition.ogg` `bgm_ending.ogg` | Stability AI `stable-audio-2.5` | `audio/sound-manifest.json` | Stability AI 약관상 상업적 사용 가능(유료 크레딧 생성물) | ffmpeg 꼬리→머리 크로스페이드 루프(3s) + ogg 인코딩, seam 수치 검증 통과 | 가능 |
| `sting_positive.wav` `sting_bonding.wav` `sting_new_ending.wav` `sting_gacha_special.wav` | Stability AI `stable-audio-2.5` | 동일 | 동일 | 무음 트림 | 가능 |
| raw 원본 | `audio/raw/` 보관(무료 재처리용) — `seamtest_*.wav` 는 청취 QA 용 | — | 동일 | — | 배포 제외 |

## 외부 CC0 오디오 (assets/audio/sfx/)

| 파일 | 원본 | 출처 | 라이선스 | 수정 | 마켓 사용 |
| --- | --- | --- | --- | --- | --- |
| `tap.ogg` | click_001.ogg | Kenney "Interface Sounds" 1.0 (kenney.nl/assets/interface-sounds) | CC0 1.0 (크레딧 불요) | 파일명 변경만 | 가능 |
| `page.ogg` | select_001.ogg | 동일 | CC0 1.0 | 동일 | 가능 |
| `chime.ogg` | confirmation_001.ogg | 동일 | CC0 1.0 | 동일 | 가능 |
| `stress_nudge.ogg` | bong_001.ogg | 동일 | CC0 1.0 | 동일 | 가능 |

## 폰트 (game/ui/fonts/)

| 파일 | 출처 | 라이선스 | 마켓 사용 |
| --- | --- | --- | --- |
| GothicA1-ExtraBold.ttf / BlackHanSans-Regular.ttf / DoHyeon-Regular.ttf | Google Fonts | SIL OFL 1.1 (`game/ui/fonts/LICENSE.md`) | 가능(임베딩 허용) |

## 청취 QA (사후 검수 — DEC-033)

```bash
afplay assets/audio/raw/seamtest_bgm_home.wav        # 루프 이음매 = 중간 지점
afplay assets/audio/raw/seamtest_bgm_transition.wav
afplay assets/audio/raw/seamtest_bgm_ending.wav
afplay assets/audio/sting_positive.wav
afplay assets/audio/sting_bonding.wav
afplay assets/audio/sting_new_ending.wav
afplay assets/audio/sting_gacha_special.wav
afplay assets/audio/sfx/tap.ogg
```
