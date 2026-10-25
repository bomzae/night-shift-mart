---
name: gameplay-development
description: NIGHT SHIFT MART의 gameplay 기능 구현과 기존 gameplay 표현 개선 시 물리 상호작용, 빠른 조작감, 범위를 유지한다.
---
# Gameplay Development

## Purpose
새 Gameplay 시스템 또는 기존 플레이 표현을 구현할 때 사용한다. 먼저 루트 PROJECT_NOTES.md와 관련 코드를 읽는다.

## Principles
- **Toy First:** 특정 용도로만 제한하지 않고 기존 물리와 연결한다. 카트는 운반/탑승/장난/공격, 상품은 진열/판매/투척, Character Carry는 취객 및 향후 미아에 재사용한다.
- **Gameplay Before Realism:** 실제 마트/물리 재현보다 템포와 반응성을 우선한다. 카트는 현실보다 민첩해도 된다.
- **Do Not Lock Player:** 업무 중 이동/Grab/Toy Interaction을 유지한다. 계산 등의 이유로 전체 입력을 잠그지 않는다.
- **Prefer System Interaction:** 별도 연출 이벤트보다 기존 시스템 결합으로 상황을 만든다. 물리 상품을 숫자 인벤토리로 대체하지 않는다.
- **Contextual Product Info:** Shelf/Category 이름은 표시하되 상품 가격·무게·음식 정보는 조준한 대상에만 표시한다. Customer 구매 아이콘과 도구 상태 피드백은 유지한다.
- **Loose Cargo:** 카트 적재물은 실제 RigidBody로 유지한다. 평상시 낮은 상대 속도의 적재물에만 약한 안정화를 허용하며 Grab·Launch·강한 충격·전복에서는 자유롭게 이탈해야 한다.
- **Monster Contact:** 사람과의 hard collision이 군중 정체를 만들면 이동 충돌과 공격 Hit Area를 분리한다. World·Cart·상품의 물리 충돌은 유지하고, pair exception은 대상 제거 전에 양쪽에서 정리한다.
- **Prototype Scope:** 요청된 목표를 먼저 완성하고 다음 콘텐츠/복잡한 추상 계층을 만들지 않는다.
- **Manual Feel Test:** 자동 통과만으로 손맛을 확정하지 않는다. 재미있는가, 답답하지 않은가, 즉각적인가, 다른 시스템과 상황을 만드는가를 직접 확인할 절차를 보고한다. 실제 수행하지 않은 수동 검사를 통과라고 쓰지 않는다.
