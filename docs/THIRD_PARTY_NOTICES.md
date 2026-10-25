# 数据来源与第三方说明

本项目为本地输入法验证工程。所有输入识别在本机执行。

- CC-CEDICT：由社区维护，MDBG 发布；中文词条与读音源自该词典。采用 Creative Commons Attribution-ShareAlike 4.0 International。保留原始压缩词典，头部包含版权和许可链接。派生中文数据按相同 CC-BY-SA-4.0 条件提供，可通过 `scripts/prepare_data.py` 重建。参考来源包括 CEDICT，Copyright (C) 1997, 1998 Paul Andrew Denisowski。下载来源：https://www.mdbg.net/chinese/dictionary?page=cc-cedict 。许可：https://creativecommons.org/licenses/by-sa/4.0/ 。
- jieba：只用于提供词频和词性，不声称它们是教学规范；MIT 许可全文保留在 `data/upstream/jieba-LICENSE`。原始数据和派生过程保留。
- CMU Pronouncing Dictionary：英文词形源自 cmudict，许可证全文保留在 `data/upstream/cmudict-LICENSE`。本项目提取去掉发音及变体编号的英文词形，不能将词典成员资格称为常用词概率。
- 项目自行整理的常用技术缩写、少量英文功能词和词性转移排序：属于原型启发式配置，尚未经过大规模意图数据校准。
- librime：本次只阅读 C API 头文件评估集成，没有链接 librime 运行库。该头文件保留于 `data/upstream/rime_api.h`，标有 BSD 许可。下一阶段若集成应单独携带完整许可证和所有词库许可证。

各文件获取日期与 SHA-256 记录在 `sources.json`。当前下载网址部分为上游 master；原始文件和哈希保证此版本可复现，不能将未来重新下载结果视为同一版本。

拼音音节表从 CC-CEDICT 输入读音抽取，含边缘音节，不代表已完成《汉语拼音方案》全部规范审核。教学用途待人工审校。

## Windows安装包补充（2026-10-20）

Windows交叉编译版静态链接LLVM/MinGW运行时，相关原始版权声明保留在 `windows/ThirdParty`；NSIS安装器运行部分的许可同样保留。Windows发行包在ThirdParty子目录随包携带这些文本。它们不改变中文派生词库的CC-BY-SA-4.0声明。
