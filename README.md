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

아래 수치는 제출 당시 보고서에 기록된 결과이며, 현재 GitHub Actions에서 UVM 테스트를 다시 실행한 결과는 아닙니다.

- **SPI UVM:** 38 PASS / 0 FAIL
- **I2C UVM:** 7 PASS / 0 FAIL
- **UART/FIFO:** random stimulus, parity-error injection, reference queue 기반 자동 비교

## Implemented Techniques

- UVM Sequence Item, Sequence, Sequencer, Driver, Monitor, Agent, Environment, Test
- Factory, Phase/Objection, Config DB 기반 virtual interface 전달
- Analysis Port/Imp 기반 Monitor → Scoreboard·Coverage 연결
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

> 공개 Runner의 CI는 합성 가능한 DUT 구문·연결을 확인합니다. UVM 1.2 시나리오와 Coverage 결과는 VCS 환경에서 수행한 검증 결과와 분리해 표기합니다.

| Evidence | 확인할 수 있는 범위 |
|---|---|
| [SPI/I2C 검증 시나리오와 실행 명령](./uvm-spi-i2c-verification#run) | 공개된 DUT·UVM TB를 VCS/UVM 1.2 환경에서 실행하는 방법 |
| [UART/FIFO Simulation Sets](./systemverilog-uart-fifo-verification#simulation-sets) | FIFO, UART, 통합 Loopback의 개별 컴파일 구성 |
| [CI 실행 기록](https://github.com/lsy49055089/RTL-Verification-Projects/actions/workflows/rtl-ci.yml) | SPI·I2C·UART/FIFO DUT의 elaboration 성공 여부 |

원본 UVM 실행 로그와 Coverage database는 현재 공개 저장소에 포함되지 않았습니다. 따라서 CI 배지를 전체 UVM 시나리오나 Coverage 목표의 통과 근거로 사용하지 않습니다.

---

## Portfolio Navigation

[Conference Paper](https://github.com/lsy49055089/Parallel-Decision-Tree-Hardware) · [RTL / FPGA Design](https://github.com/lsy49055089/RTL-Design-Projects) · [Design Verification](https://github.com/lsy49055089/RTL-Verification-Projects) · [Embedded Systems](https://github.com/lsy49055089/Embedded-Systems-Projects) · [Edge AI / CV](https://github.com/lsy49055089/AI-Projects)
