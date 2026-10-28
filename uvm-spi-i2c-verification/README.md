# SPI · I2C UVM Verification

SPI·I2C RTL과 UVM 검증 환경을 구현해 각각 10,000건을 시험하고, SPI 파형을 Basys3에서 확인했습니다.


[개요](#개요) · [담당 역할](#담당-역할) · [설계·구현](#설계구현) · [검증 결과](#검증-결과) · [실행 방법](#실행-방법)

## 개요

| 항목 | 내용 |
|---|---|
| 기술 | SystemVerilog · UVM 1.2 · VCS · Verdi · Basys3 |
| 검증 조건 | 2026.10.19–20 · VCS W-2024.09-SP2 · seed 1234 |


## 담당 역할

- SPI Mode 0 Master/Slave와 I2C Master/Slave RTL 구현
- UVM Sequence·Driver·Scoreboard·Coverage 구성, SPI Monitor와 I2C 완료 시점 샘플링 구현
- 정상·오류 트랜잭션 자동 비교와 SPI FPGA 파형 확인


## 설계·구현

<a id="highlights"></a>

### 구현 항목

| Area | Implementation |
|---|---|
| SPI RTL | 8-bit Mode 0 Master/Slave, full-duplex MOSI/MISO, programmable clock divider, loopback top |
| I2C RTL | START/STOP, Write/Read, ACK/NACK, address match, open-drain SDA |
| UVM | Sequence Item, Sequence, Sequencer, Driver, Monitor, Agent, Environment, Test, Factory, Config DB |
| Self-checking | Analysis Port/Imp, scoreboard PASS/FAIL, protocol status checks |
| Coverage | I2C operation, ACK/NACK, address match, R/W mode, data bins; operation × ACK / address match / R/W crosses |
| Hardware | Basys3 Master/Slave wrappers, button debounce, LED/FND status, logic-analyzer validation |

<a id="architecture"></a>

### 검증 환경 구조

![SPI and I2C UVM verification architecture](assets/uvm-architecture.svg)

Sequence가 만든 트랜잭션을 Sequencer·Driver를 통해 DUT에 전달합니다. SPI Monitor는 완료된 전송을 수집하고, I2C Driver는 명령 완료 시점의 DUT 상태·데이터를 수집합니다. 각 결과는 Analysis Port를 통해 Scoreboard와 Coverage로 전달합니다.


## 검증 결과

<a id="verification-scenarios"></a>

### 검증 시나리오

| Target | Stimulus | Automated Checks |
|---|---|---|
| SPI directed | 8 pattern pairs: `AA/11`, `55/22`, `00/33`, `FF/44`, `0F/55`, `F0/66`, `A5/77`, `5A/88` | MOSI/MISO data integrity and Master/Slave busy/done state |
| SPI random | **9,992 randomized Master/Slave byte pairs** | Full-duplex receive data against both transmitted bytes |
| I2C write | 1 directed case + 2,499 randomized cases = **2,500 transactions** | Write ACK and Slave receive data |
| I2C read | 1 directed case + 2,499 randomized cases = **2,500 transactions** | Master receive data and final NACK |
| I2C write-read | 1 directed case + 2,499 randomized cases = **2,500 transactions** | Write/read data checks; STOP then START (not repeated START) |
| I2C wrong address | 1 directed case + 2,499 randomized cases = **2,500 transactions** | Address mismatch and NACK |

<a id="results"></a>

### 검증 요약

**SPI·I2C 자동 검증**

검증 조건 · 2026.10.19–20 · Synopsys VCS W-2024.09-SP2 · UVM 1.2 · random seed `1234`

| Target | Transactions | Scoreboard PASS checks | FAIL | Functional coverage |
|---|---:|---:|---:|---:|
| SPI Mode 0 | **10,000** (8 directed + 9,992 random) | **10,000** | **0** | Defined in source; numeric result not retained here |
| I2C | **10,000** (4 operations × 2,500) | **17,500** | **0** | **83.33%** |

SPI·I2C 시뮬레이션 결과는 모두 **UVM_ERROR: 0, UVM_FATAL: 0**입니다. SPI checks a completed full-duplex transfer once per transaction; I2C checks two conditions for Write, Read, and Write-Read and one for Wrong Address, producing 17,500 individual PASS checks from 10,000 transactions. **PASS check count is not the number of distinct scenarios.**

I2C coverpoint metrics for operation, ACK/NACK, address match, R/W mode, and data were each 100%. Three defined crosses (operation × ACK, address match, R/W) each reached **50%**, contributing to the 83.33% aggregate. Coverage는 정의한 Bin을 기준으로 집계했습니다. 미도달 조건은 잘못된 주소 Read와 Write-Read의 중간 Write 관찰입니다.

<details>
<summary>2026.06 검증 결과</summary>

SPI **38 PASS / 0 FAIL**, I2C **7 PASS / 0 FAIL**입니다. I2C는 Directed Transaction 4건에서 7개 항목을 검사했습니다.

</details>

**실행 자료:** VCS 원본 로그 `spi_10k.log`·`i2c_10k.log`는 별도 보관하며 저장소에는 포함하지 않았습니다. GitHub Actions에서는 DUT elaboration을 검사합니다. UVM 검증은 아래 VCS 명령으로 실행하며, Basys3의 SPI 파형은 Logic Analyzer로 확인했습니다.

<a id="troubleshooting-applied"></a>

### 문제 해결

- Stabilized FPGA SPI decoding by changing the board clock divider from `8'd4` to `8'd100`.
- Fixed the first MISO-bit timing by presenting `tx_data[7]` immediately when `SS_N` falls.
- Implemented I2C SDA as open drain: logic `1` releases the line to `Z`; logic `0` drives it low.
- Delayed SPI monitor sampling by `#1` after the start edge to observe RTL nonblocking-assignment updates correctly.


## 실행 방법

<a id="run"></a>

### VCS 실행

From `uvm-spi-i2c-verification/` on a machine with VCS/UVM 1.2, compile the checked-in sources and run each regression separately:

```bash
vcs -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm-1.2 \
  -f sim/spi.f -top tb_top_spi_loopback -debug_access+all \
  -o simv_spi_10k -l compile_spi_10k.log
./simv_spi_10k +ntb_random_seed=1234 > spi_10k.log 2>&1

vcs -full64 -sverilog -timescale=1ns/1ps -ntb_opts uvm-1.2 \
  -f sim/i2c.f -top tb_top -debug_access+all \
  -o simv_i2c_10k -l compile_i2c_10k.log
./simv_i2c_10k +ntb_random_seed=1234 > i2c_10k.log 2>&1
```

The SV testbenches gate FSDB generation on `+DUMP_FSDB`, so the commands above do not request waveform dumps. If enabled, the setup needs compatible Verdi FSDB PLI. Simulator/version/tool licensing may affect reproducibility. Review the final Scoreboard and UVM report summaries; do not treat successful compilation as proof of PASS.

### 검증 조건

- SPI is limited to one Master, one Slave and Mode 0.
- I2C does not yet cover multi-master arbitration, clock stretching, multiple Slaves or external sensors.
- SVA protocol properties, code coverage, SPI의 다른 CPOL/CPHA 모드와 I2C repeated START는 검증 범위에 포함하지 않았습니다.

<a id="repository-structure"></a>

### 디렉터리

```text
.
├── rtl
│   ├── spi          # SPI Master, Slave and simulation loopback
│   └── i2c          # I2C Master, Slave and connected top
├── fpga             # Basys3 demo wrappers, control IP and FND display
├── tb               # SPI and I2C UVM testbenches
├── sim              # Compile-order file lists
└── assets           # Portfolio architecture diagram
```


---

[웹 포트폴리오](https://seungyeol-rtl-portfolio.azuretide33.chatgpt.site) · [GitHub 프로필](https://github.com/lsy49055089)

[논문](https://github.com/lsy49055089/Parallel-Decision-Tree-Hardware) · [RTL / FPGA Design](https://github.com/lsy49055089/RTL-Design-Projects) · [Design Verification](https://github.com/lsy49055089/RTL-Verification-Projects) · [Embedded Systems](https://github.com/lsy49055089/Embedded-Systems-Projects) · [AI / CV](https://github.com/lsy49055089/AI-Projects)
