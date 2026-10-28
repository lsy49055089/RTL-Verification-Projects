# Design Verification

SystemVerilog·UVM으로 RTL 데이터와 프로토콜 상태를 자동 비교하고, 오류 조건을 검증한 프로젝트입니다.


<a id="design-verification-projects"></a>
<a id="projects"></a>
<a id="verified-results"></a>
<a id="implemented-techniques"></a>
<a id="continuous-integration"></a>
<a id="portfolio-navigation"></a>

## 프로젝트

| 프로젝트 | 담당 역할 | 주요 구현·결과 |
|---|---|---|
| [SPI · I2C UVM Verification](./uvm-spi-i2c-verification) | SPI/I2C RTL·UVM·Scoreboard·Coverage | 각각 10,000건·0 FAIL, I2C Functional Coverage 83.33% |
| [UART · FIFO · Parity Verification](./systemverilog-uart-fifo-verification) | UART/FIFO RTL·Class-based TB·오류 주입 | FIFO 순서·Loopback 비교, Parity 오류 검출·전송 차단 |

## 검증 결과

검증 조건 · 2026.10.19–20 · VCS W-2024.09-SP2 · UVM 1.2 · seed 1234

| 항목 | SPI | I2C |
|---|---|---|
| 트랜잭션 | 10,000건 | 10,000건 |
| Scoreboard 검사 | 10,000 PASS / 0 FAIL | 17,500 PASS / 0 FAIL |
| 입력 조건 | Directed 8 + Random 9,992 | WRITE / READ / WR_RD / WRONG_ADDR 각각 2,500회 |
| Functional Coverage | 수치 미기재 | 83.33% · Coverpoint 6개 100%, Cross 3개 각각 50% |

I2C는 한 트랜잭션에서 여러 항목을 검사하므로 트랜잭션 수와 검사 수가 다릅니다. AXI4-Lite 프로젝트의 SPI 32/32·I2C 30/30 시험은 별도 환경의 결과입니다.

## 검증·실행

- **SPI:** Monitor가 완료된 전송을 수집해 Scoreboard와 Coverage로 전달합니다.
- **I2C:** Driver가 명령 완료 시점의 DUT 상태·데이터를 수집해 Scoreboard와 Coverage로 전달합니다.
- **UART/FIFO:** Class·Virtual Interface·Mailbox·Event로 구성한 테스트벤치에서 Queue·기대값과 DUT 결과를 비교합니다.

GitHub Actions는 Icarus Verilog로 DUT의 구문과 모듈 연결(elaboration)을 검사합니다.

```bash
bash scripts/check_rtl.sh
```

UVM 시뮬레이션에는 VCS/UVM 1.2가 필요합니다. 10,000건 실행의 VCS 원본 로그는 별도 보관하며 저장소에는 포함하지 않았습니다. CI 검사는 UVM 트랜잭션 시험과 구분합니다.

- [SPI/I2C 실행 명령과 검증 조건](./uvm-spi-i2c-verification#run)
- [UART/FIFO 시뮬레이션 구성](./systemverilog-uart-fifo-verification#simulation-sets)
- [CI 실행 기록](https://github.com/lsy49055089/RTL-Verification-Projects/actions/workflows/rtl-ci.yml)


---

[웹 포트폴리오](https://seungyeol-rtl-portfolio.azuretide33.chatgpt.site) · [GitHub 프로필](https://github.com/lsy49055089)

[논문](https://github.com/lsy49055089/Parallel-Decision-Tree-Hardware) · [RTL / FPGA Design](https://github.com/lsy49055089/RTL-Design-Projects) · [Design Verification](https://github.com/lsy49055089/RTL-Verification-Projects) · [Embedded Systems](https://github.com/lsy49055089/Embedded-Systems-Projects) · [AI / CV](https://github.com/lsy49055089/AI-Projects)
