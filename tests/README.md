# APB 주소/기본 응답 회귀 테스트

`run_apb_address.cmd`를 실행합니다. 기본 도구 경로는
`C:\Xilinx\Vivado\2023.2\bin`이며, 다른 설치 경로는 `VIVADO_BIN` 환경 변수로 지정합니다.
실행 결과와 컴파일 산출물은 `tests/build/`에 생성됩니다.

테스트는 실제 `rv32i_mcu`를 사용합니다. 처음에는 CPU 요청 신호만 force하여
77건의 버스 전송을 검사하고, 이후 force를 해제하고 리셋하여 원래 CPU 프로그램을 실행합니다.

- RAM 첫/마지막 워드와 정상 주변장치 레지스터 읽기/쓰기
- 예약 영역, 다른 상위 주소가 실제 슬레이브로 중복 매핑되지 않는지 검사
- 모든 주변장치의 미정의 offset 읽기는 0 반환, 쓰기는 기존 값 보존
- IDLE/SETUP에서 완료 응답이 없는지 검사
- 선택된 RAM의 응답을 지연해 주소/제어 유지와 완료 대기 검사
- 원래 `apb_bram.mem` 실행 결과: RAM[0:2] 및 x13/x12/x11에 0x41/0x42/0x43

잘못된 주소를 의도적으로 사용하므로 `Warning: ... unmapped ...`는 예상된 출력입니다.
성공 시 다음 두 메시지가 출력되고 실행 스크립트는 종료 코드 0을 반환합니다.

```text
PASS: 77 APB transfers; boundaries, aliasing, offsets, waits
PASS: original program apb_bram.mem stores and loads 41/42/43
```

## 이번 변경의 동작

`master.sv`의 디코더는 `[31:12]`를 비교해 각 슬레이브에 정확히 4KiB를 할당합니다.
응답 MUX는 주소를 다시 해석하지 않고 동일한 PSEL 벡터를 사용합니다.
읽기 데이터는 SETUP에서도 전달하며, Ready는 ACCESS에서만 전달합니다.
선택된 슬레이브가 없으면 ACCESS에서 데이터 0과 완료 응답을 반환합니다.
GPIO/FND/UART의 미정의 offset 반환값을 X에서 0으로 변경했습니다.
GPO/GPI는 기존의 0 반환을 유지합니다. 미정의 offset 쓰기는 기존처럼 무시합니다.
잘못된 주소 접근 경고는 `synthesis translate_off/on`으로 합성에서 제외합니다.

이 정책은 CPU에 오류 상태를 전달하지 않습니다. 소프트웨어는 오류로 반환된 0과
정상 데이터 0을 구분할 수 없습니다. 유효한 레지스터에서 발생하는 X/Z는 숨기지 않습니다.
RAM 크기, 정렬 처리, 바이트/하프워드 지원은 변경하지 않았습니다.
이 테스트는 전체 명령어/주변장치 검증이나 FPGA 합성·타이밍 검증을 대신하지 않습니다.

## Load의 MEM/WB 타이밍 수정

`rv32i_cpu.sv`는 Load의 MEM 상태에서 ready를 기다린 뒤 WB로 이동합니다.
`rv32i_datapath.sv`의 `U_MEM_REG_DRDATA`는 별도 enable 없이 일반 `register`로
매 클럭 bus_rdata를 저장합니다. MEM 완료 에지에 저장한 값은 다음 WB 에지 직전까지 유지됩니다.
WB는 ready를 다시 기다리지 않고 rf_we를 활성화하여, WB를 끝내는 클럭에서
중간 레지스터의 에지 직전 값을 register file에 저장합니다. 같은 에지에서 중간 레지스터가
새 버스 값으로 갱신되더라도 논블로킹 대입 때문에 register file 쓰기에는 영향을 주지 않습니다.
WB는 한 사이클이며 Store의 완료 흐름은 유지합니다.

`run_load_timing.cmd`는 위의 APB 회귀 테스트 실행 후 `tb_load_timing.sv`를 실행합니다.
CPU와 APB 마스터는 실제 RTL 그대로 사용하고, RAM 응답 신호만 테스트에서 제어합니다.
읽기 데이터는 SETUP/대기 중에는 0xDEADBEEF, 완료 사이클에만 정상 값으로 바뀝니다.

- 추가 대기 0/1/4사이클에서 완료 데이터를 정확히 저장하는지 확인
- 완료 에지에서는 중간 레지스터만 쓰고 다음 에지에서 목적 레지스터를 쓰는지 확인
- WB에서는 ready가 내려가고 버스 데이터가 바뀌어도 이전 에지에서 저장한 완료 데이터를 쓰는지 확인
- 읽기 요청/응답이 중복되지 않는지 확인 (3회 읽기, 4회 쓰기)
- 마지막 Load 결과를 바로 사용하는 ADDI와 Store 결과 0x44 확인

성공 메시지: `PASS: load timing; 0/1/4 wait cycles, capture then WB, no duplicate requests, dependent ALU/store`
