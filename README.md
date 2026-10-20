# Design Verification Projects

SystemVerilog와 UVM을 사용해 RTL 기능과 프로토콜 동작을 검증한 프로젝트를 정리한 포트폴리오 저장소입니다.

**Portfolio focus:** self-checking testbench · UVM · scoreboard · functional coverage

[![Verification RTL CI](https://github.com/lsy49055089/RTL-Verification-Projects/actions/workflows/rtl-ci.yml/badge.svg)](https://github.com/lsy49055089/RTL-Verification-Projects/actions/workflows/rtl-ci.yml)

> **Related Conference Paper Verification:** [Parallel Decision Tree Hardware](https://github.com/lsy49055089/Parallel-Decision-Tree-Hardware) — 37개 벡터 전수 분류, DONE-state assertion, 6-state/4-state 결과 동등성과 batch cycle을 자동 비교합니다.

## Projects

| Project | Verification Target | Key Techniques |
|---|---|---|
| [SPI & I2C UVM Verification](./uvm-spi-i2c-verification) | SPI Mode 0, I2C Write/Read/ACK/NACK, FPGA 실측 | UVM 1.2, factory, config DB, analysis port, scoreboard, functional coverage |
| [UART + FIFO + Parity Verification](./systemverilog-uart-fifo-verification) | UART RX/TX, dual FIFO, Odd Parity, error blocking | Class-based TB, mailbox, virtual interface, random stimulus, scoreboard |

## Verified Results

**검증 환경·출처:** Synopsys VCS W-2024.09-SP2 / UVM 1.2 · 2026-10-19~20 추가 검증 (seed 1234, 당시 실행 로그 기준).

- **SPI UVM:** **10,000 Transactions / 10,000 Scoreboard PASS / 0 FAIL** (Directed 8 + Random 9,992)
- **I2C UVM:** **10,000 Transactions / 17,500 Scoreboard PASS Checks / 0 FAIL**, Functional Coverage **83.33%** (정의한 커버리지 Bin 기준; Cross 3개 항목 각각 50%)
- **과거 제출 결과:** SPI 38 PASS, I2C 7 PASS (2026-06, 확장 전)
- **UART/FIFO:** random stimulus, parity-error injection, reference queue 기반 자동 비교

## Implemented Techniques

- UVM Sequence Item, Sequence, Sequencer, Driver, Monitor, Agent, Environment, Test
- Factory, Phase/Objection, Config DB 기반 virtual interface 전달
- Analysis Port/Imp 기반 Scoreboard·Coverage 연결 (SPI Monitor 수집, I2C Driver 완료 시점 샘플링)
- I2C ACK/NACK, Address Match, R/W, Data 및 cross functional coverage
- Class-based Transaction, Generator, Driver, Monitor, Scoreboard
- Typed mailbox, event, virtual interface 기반 component synchronization
- Queue/reference data 기반 자동 PASS/FAIL 비교
- Reset immediate assertion 및 waveform timing 분석

각 프로젝트 폴더에는 DUT, testbench, 검증 시나리오, 결과와 재현 시 주의사항을 정리했습니다.


## Continuous Integration

GitHub Actions에서 Icarus Verilog로 SPI, I2C, UART/FIFO DUT의 SystemVerilog elaboration을 자동 검사합니다.

```bash
bash scripts/check_rtl.sh
```

**CI 검사 범위:** SPI·I2C·UART/FIFO DUT의 구문과 모듈 연결.

| Evidence | 확인할 수 있는 범위 |
|---|---|
| [SPI/I2C 검증 시나리오와 실행 명령](./uvm-spi-i2c-verification#run) | 공개된 DUT·UVM TB를 VCS/UVM 1.2 환경에서 실행하는 방법 |
| [UART/FIFO Simulation Sets](./systemverilog-uart-fifo-verification#simulation-sets) | FIFO, UART, 통합 Loopback의 개별 컴파일 구성 |
| [CI 실행 기록](https://github.com/lsy49055089/RTL-Verification-Projects/actions/workflows/rtl-ci.yml) | SPI·I2C·UART/FIFO DUT의 elaboration 성공 여부 |

**UVM 재현 환경:** VCS/UVM 1.2가 필요합니다. 10,000건 검증 실행 로그는 사용자 Linux 서버에 보관되어 있으며 이 저장소에는 포함하지 않습니다. CI 성공은 UVM 10,000건 실행을 의미하지 않습니다. 명령과 검증 범위는 [프로젝트 README](./uvm-spi-i2c-verification#run)를 확인하세요.

---

## Portfolio Navigation

[Conference Paper](https://github.com/lsy49055089/Parallel-Decision-Tree-Hardware) · [RTL / FPGA Design](https://github.com/lsy49055089/RTL-Design-Projects) · [Design Verification](https://github.com/lsy49055089/RTL-Verification-Projects) · [Embedded Systems](https://github.com/lsy49055089/Embedded-Systems-Projects) · [Edge AI / CV](https://github.com/lsy49055089/AI-Projects)
