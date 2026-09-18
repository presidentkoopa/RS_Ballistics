# RS_Ballistics effect sprites: where each came from

Written by `tools/import_fx.py`. Not packed (build.ps1 packs an allowlist).

- **Copied** frames come from RS_Main's combat effects, cleared by the owner on
  2026-09-14 ("RS_Main is fair game"). SHA-1 is of the RS_Main source file.
- **Generated** frames are made by the script from a fixed seed and are owned outright.


## RSDS: rolling dust and smoke cloud, greyscale (tinted per material)

- `sprites/RSDSA0.png` from `RS_Main/sprites/combatfx/blast/JSMOA0` (sha1 fb4584c9ad9a98e85accc7d2aaf299cd72c45af0)
- `sprites/RSDSB0.png` from `RS_Main/sprites/combatfx/blast/JSMOB0` (sha1 7589b059bf95eebb529bdbc95cebbc97f94b6170)
- `sprites/RSDSC0.png` from `RS_Main/sprites/combatfx/blast/JSMOC0` (sha1 bb0201bcea3177913db30924161cf934453ae3a5)
- `sprites/RSDSD0.png` from `RS_Main/sprites/combatfx/blast/JSMOD0` (sha1 7cc3863c4a58f70c971145122fa187373fa3adc0)
- `sprites/RSDSE0.png` from `RS_Main/sprites/combatfx/blast/JSMOE0` (sha1 e337f07ac91ff07c25d9123058cee83c1f88eed3)
- `sprites/RSDSF0.png` from `RS_Main/sprites/combatfx/blast/JSMOF0` (sha1 32fc7019497ad5009733cec087ce7700fe97e71e)
- `sprites/RSDSG0.png` from `RS_Main/sprites/combatfx/blast/JSMOG0` (sha1 06bfbbd21b03f50dd009c6b019051d08b9c8b05e)
- `sprites/RSDSH0.png` from `RS_Main/sprites/combatfx/blast/JSMOH0` (sha1 26b3d5e9dddf8b081498cdadd5fc28697d3ba627)
- `sprites/RSDSI0.png` from `RS_Main/sprites/combatfx/blast/JSMOI0` (sha1 40d7ed49b248edc349291cb3933c15f1795843f8)
- `sprites/RSDSJ0.png` from `RS_Main/sprites/combatfx/blast/JSMOJ0` (sha1 a9d9c9c5908dc73b26b133c2de9737d75a238044)
- `sprites/RSDSK0.png` from `RS_Main/sprites/combatfx/blast/JSMOK0` (sha1 7069186fb0fe469a383ca8bd9a1d6d394254fd68)
- `sprites/RSDSL0.png` from `RS_Main/sprites/combatfx/blast/JSMOL0` (sha1 817d95fb397447a5d742c48f0b1546f1bbb811c6)
- `sprites/RSDSM0.png` from `RS_Main/sprites/combatfx/blast/JSMOM0` (sha1 38348c0b6ac5ac1cae3750f265729923b5ac4352)
- `sprites/RSDSN0.png` from `RS_Main/sprites/combatfx/blast/JSMON0` (sha1 bd835f1d343614e4baa73464cc56ef8943e8f263)
- `sprites/RSDSO0.png` from `RS_Main/sprites/combatfx/blast/JSMOO0` (sha1 e41d7707c043bad2a1762748709862d1309a2966)
- `sprites/RSDSP0.png` from `RS_Main/sprites/combatfx/blast/JSMOP0` (sha1 2246a4dfa28b541ac34a5497f86d1e22fdc4de99)
- `sprites/RSDSQ0.png` from `RS_Main/sprites/combatfx/blast/JSMOQ0` (sha1 31507428980a316c82c034f2579c1039e2f5319a)
- `sprites/RSDSR0.png` from `RS_Main/sprites/combatfx/blast/JSMOR0` (sha1 7d49ab9ad0cfdf7a2f2f98ebbf78507cbf8bfbab)

## RSFB: fireball burning out

- `sprites/RSFBA0.png` from `RS_Main/sprites/combatfx/fire/RSI4A0.png` (sha1 2f4612937a1d0ea2162e47611206262b3eed515c)
- `sprites/RSFBB0.png` from `RS_Main/sprites/combatfx/fire/RSI4B0.png` (sha1 b8386bb488954351ef4b9e84aff698c0f9e8e482)
- `sprites/RSFBC0.png` from `RS_Main/sprites/combatfx/fire/RSI4C0.png` (sha1 49d0ce66a849470cca454017d6c3f9de727a1785)
- `sprites/RSFBD0.png` from `RS_Main/sprites/combatfx/fire/RSI4D0.png` (sha1 b1eb97f29a5f33aec0102de00d26a181cf4a542e)
- `sprites/RSFBE0.png` from `RS_Main/sprites/combatfx/fire/RSI4E0.png` (sha1 92236ebe1010613a8e201c5cdff3584ec192deb5)
- `sprites/RSFBF0.png` from `RS_Main/sprites/combatfx/fire/RSI4F0.png` (sha1 9e7091114a5ed71335c90599c90c83a0965361cb)
- `sprites/RSFBG0.png` from `RS_Main/sprites/combatfx/fire/RSI4G0.png` (sha1 938e690fdb5331f76b5b1ba7ecfad25954ea6f70)
- `sprites/RSFBH0.png` from `RS_Main/sprites/combatfx/fire/RSI4H0.png` (sha1 bd1f4a39bc6d6ea0aeffe0eef79b1d7a0000f4f4)

## RBVF: volumetric fireball cooling to smoke (generated: tools/gen_flipbooks.py, seed 3200)

- `textures/RBVF0001.dds` .. `textures/RBVF0064.dds` generated: a 3D density field raymarched per frame, BC7 (the
  script's own mode-6 encoder), premultiplied, full mip chain, 512 px. Owned outright. For the engine's compressed
  particle atlas (cf3dba0d6f); the rocket and RPG blasts' `rsb_fireball` draws it.

## RSFL: flame tongues

- `sprites/RSFLA0.png` from `RS_Main/sprites/combatfx/fire/RSI3a0.png` (sha1 3bc326c5ee9df9f16522557bca1b91ec6bfd8d69)
- `sprites/RSFLB0.png` from `RS_Main/sprites/combatfx/fire/RSI3b0.png` (sha1 6ddf4c19f0659baa62b8feb8b3d4e66168eee8a5)
- `sprites/RSFLC0.png` from `RS_Main/sprites/combatfx/fire/RSI3c0.png` (sha1 1a482988be1a810cc68e6fb18983c40b8c88ece3)
- `sprites/RSFLD0.png` from `RS_Main/sprites/combatfx/fire/RSI3d0.png` (sha1 2edf0b1b67fc8228e028995aa3546fe90980070b)
- `sprites/RSFLE0.png` from `RS_Main/sprites/combatfx/fire/RSI3e0.png` (sha1 d65fb8b55c8ff2162f4bb19ad61079c77669313d)
- `sprites/RSFLF0.png` from `RS_Main/sprites/combatfx/fire/RSI3f0.png` (sha1 4185fa3cbbce0afaf10a1d96c6f02537490e979f)
- `sprites/RSFLG0.png` from `RS_Main/sprites/combatfx/fire/RSI3g0.png` (sha1 c68b092ec6c1de162c5b9fd49c254ce400441fea)
- `sprites/RSFLH0.png` from `RS_Main/sprites/combatfx/fire/RSI3h0.png` (sha1 4a5d37d269f6086eb987e761391b353f6859b178)

## RSFK: a single rising flame lick

- `sprites/RSFKA0.png` from `RS_Main/sprites/combatfx/fire/RSI8A0.png` (sha1 ae4d0abd2e18640f40f90f8de61c622171d8de48)
- `sprites/RSFKB0.png` from `RS_Main/sprites/combatfx/fire/RSI8B0.png` (sha1 130eed25923ae9a7f5580ac0a473410b28f12dd6)
- `sprites/RSFKC0.png` from `RS_Main/sprites/combatfx/fire/RSI8C0.png` (sha1 ac8eb0e831a198dcbfbdb5fc11b7de3a84f1b516)
- `sprites/RSFKD0.png` from `RS_Main/sprites/combatfx/fire/RSI8D0.png` (sha1 cf794ab1267de40351188186798addf7bfc199da)
- `sprites/RSFKE0.png` from `RS_Main/sprites/combatfx/fire/RSI8E0.png` (sha1 8192f0fc832635788f7a40d014c054ac8ea6b820)
- `sprites/RSFKF0.png` from `RS_Main/sprites/combatfx/fire/RSI8F0.png` (sha1 93cd499ad8e8a9b232fb24e6ff3cb106095a126a)
- `sprites/RSFKG0.png` from `RS_Main/sprites/combatfx/fire/RSI8G0.png` (sha1 d47fa74993e6f2a10a7594089bce4f7b92af2ffb)
- `sprites/RSFKH0.png` from `RS_Main/sprites/combatfx/fire/RSI8H0.png` (sha1 92358f357a01b1a0a4271fdc801bf7bd2a353602)
- `sprites/RSFKI0.png` from `RS_Main/sprites/combatfx/fire/RSI8I0.png` (sha1 8736cef7c8a5893ec6acb7afe0c3a1fb8d719212)
- `sprites/RSFKJ0.png` from `RS_Main/sprites/combatfx/fire/RSI8J0.png` (sha1 f929efc3bb4ccc8892f7a1d71efc2448965d0ccb)
- `sprites/RSFKK0.png` from `RS_Main/sprites/combatfx/fire/RSI8K0.png` (sha1 fc14077b0525656e2dac78371890b8146e06143a)
- `sprites/RSFKL0.png` from `RS_Main/sprites/combatfx/fire/RSI8L0.png` (sha1 35f26943a18cd5b3cda0a381b1a79fe521983b03)
- `sprites/RSFKM0.png` from `RS_Main/sprites/combatfx/fire/RSI8M0.png` (sha1 9ad8d1adb1e4a1cb5270d9c2f87df2fc5eb852eb)
- `sprites/RSFKN0.png` from `RS_Main/sprites/combatfx/fire/RSI8N0.png` (sha1 0deee9f4cbadcbe6a440dde255a4f9e235d40ae4)
- `sprites/RSFKO0.png` from `RS_Main/sprites/combatfx/fire/RSI8O0.png` (sha1 a9149b3c95752ef8ed26fec43af2bdd8c734375b)
- `sprites/RSFKP0.png` from `RS_Main/sprites/combatfx/fire/RSI8P0.png` (sha1 ab0bd5d8c1915dda2b03bff1d7231a46da0ba675)

## RSSO: sooty puff with an ember

- `sprites/RSSOA0.png` from `RS_Main/sprites/combatfx/fire/RSI6A0.png` (sha1 72f1378c88744e8a29bdf818b3416d3a7c7dd6cb)
- `sprites/RSSOB0.png` from `RS_Main/sprites/combatfx/fire/RSI6B0.png` (sha1 495e5aea87abfe658fe0d624c8dee9badba7b92a)
- `sprites/RSSOC0.png` from `RS_Main/sprites/combatfx/fire/RSI6C0.png` (sha1 495e5aea87abfe658fe0d624c8dee9badba7b92a)
- `sprites/RSSOD0.png` from `RS_Main/sprites/combatfx/fire/RSI6D0.png` (sha1 7a8d41bf17ab439756f8aa3891c2b189014891f2)
- `sprites/RSSOE0.png` from `RS_Main/sprites/combatfx/fire/RSI6E0.png` (sha1 7a8d41bf17ab439756f8aa3891c2b189014891f2)

## RSSP: spray of hot spark streaks

- `sprites/RSSPA0.png` from `RS_Main/sprites/combatfx/sparks/RSS3A0.lmp` (sha1 cac9930990ad70a2c42d3d374b2018b60b2661c0)
- `sprites/RSSPB0.png` from `RS_Main/sprites/combatfx/sparks/RSS3B0.lmp` (sha1 e58c05c2539a971b5c733db6975b2fb8621ff70e)
- `sprites/RSSPC0.png` from `RS_Main/sprites/combatfx/sparks/RSS3C0.lmp` (sha1 5d5e6ed45f5587a8bf96d499ea1bfa55a89ca29b)
- `sprites/RSSPD0.png` from `RS_Main/sprites/combatfx/sparks/RSS3D0.lmp` (sha1 b62d227845f322e9be6b27573e20246bc7d0a9f5)
- `sprites/RSSPE0.png` from `RS_Main/sprites/combatfx/sparks/RSS3E0.lmp` (sha1 bf272d599b6008ea78a47bdd44c4a6e725bd18ae)
- `sprites/RSSPF0.png` from `RS_Main/sprites/combatfx/sparks/RSS3F0.lmp` (sha1 58803a2905f40058553f90eb519df6d80a4a9698)
- `sprites/RSSPG0.png` from `RS_Main/sprites/combatfx/sparks/RSS3G0.png` (sha1 0ef724438a8c4009e1c09b93332235225f14c175)

## RSEC: electric arc (energy weapons only)

- `sprites/RSECA0.png` from `RS_Main/sprites/combatfx/lightning/RSL2A0.png` (sha1 01aa666a265f6ea305f68035d8c02b8de2fa69f6)
- `sprites/RSECB0.png` from `RS_Main/sprites/combatfx/lightning/RSL2B0.png` (sha1 ec317275c4fd7de242b5f8ddb83f8b954d037ec2)
- `sprites/RSECC0.png` from `RS_Main/sprites/combatfx/lightning/RSL2C0.png` (sha1 8e50a96ee159bb43a3c214ca4e9a65ab09ce6b7f)
- `sprites/RSECD0.png` from `RS_Main/sprites/combatfx/lightning/RSL2D0.png` (sha1 87605a53251c30d5d2e01f221eafb1ab1d5a6bef)
- `sprites/RSECE0.png` from `RS_Main/sprites/combatfx/lightning/RSL2E0.png` (sha1 d0aaf0e493fa0b4695496219c018a6b3ccf8cb65)
- `sprites/RSECF0.png` from `RS_Main/sprites/combatfx/lightning/RSL2F0.png` (sha1 61b02b0054ce9672f6922e5b5be90454135c2558)
- `sprites/RSECG0.png` from `RS_Main/sprites/combatfx/lightning/RSL2G0.png` (sha1 c2a20e9f038a7f9c997ef6d5aa13f1945fb66d24)
- `sprites/RSECH0.png` from `RS_Main/sprites/combatfx/lightning/RSL2H0.png` (sha1 16398b962caf4c1bd1bf2b93bb3cbeafdf6a77e1)
- `sprites/RSECI0.png` from `RS_Main/sprites/combatfx/lightning/RSL2I0.png` (sha1 63b1c2c23134fd9b76338035f18192a5f3378d44)
- `sprites/RSECJ0.png` from `RS_Main/sprites/combatfx/lightning/RSL2J0.png` (sha1 de1149b535b245687beb07ed0c8a5419cdddb0ff)
- `sprites/RSECK0.png` from `RS_Main/sprites/combatfx/lightning/RSL2K0.png` (sha1 6b48504cc80996abded1e563e73ba20a1f96a5ab)
- `sprites/RSECL0.png` from `RS_Main/sprites/combatfx/lightning/RSL2L0.png` (sha1 90889cccf4e29ef551fd7b37390ead8cb3c97ea4)
- `sprites/RSECM0.png` from `RS_Main/sprites/combatfx/lightning/RSL2M0.png` (sha1 02f32faa7c50c5b11a09b777139ccac802efc0b1)

## RSCH: concrete and stone chips (generated: chip, seed 1101)

- `sprites/RSCHA0.png` generated
- `sprites/RSCHB0.png` generated
- `sprites/RSCHC0.png` generated
- `sprites/RSCHD0.png` generated

## RSSL: wood splinters (generated: splinter, seed 2203)

- `sprites/RSSLA0.png` generated
- `sprites/RSSLB0.png` generated
- `sprites/RSSLC0.png` generated
- `sprites/RSSLD0.png` generated

## RSCL: dirt clods (generated: clod, seed 3307)

- `sprites/RSCLA0.png` generated
- `sprites/RSCLB0.png` generated
- `sprites/RSCLC0.png` generated
- `sprites/RSCLD0.png` generated

## RSGS: glass shards (generated: shard, seed 4409)

- `sprites/RSGSA0.png` generated
- `sprites/RSGSB0.png` generated
- `sprites/RSGSC0.png` generated
- `sprites/RSGSD0.png` generated

## The rocket voxel (models/rocket)

- `models/rocket/rocket.kvx` from `RS_Main/voxels/MISLA.kvx` (md5 f7b380190fbec2d614d45354c0efdaa8), copied unchanged by `tools/import_rocket_voxel.py`. Byte-identical to `DXR-main/wadsrc/static/voxels/MISLA.kvx`; no author recorded in either.
- `models/rocket/rocket_pal.png` generated from that file's own palette.

## RSK*: the textured spark library (tools/import_sparks.py)

- `sprites/RSKSA0.png` from `RS_Main/sprites/combatfx/sparks/RSS4A0.png` (sha1 2b9cd8a9b271244e7ccb98edef3cb8b06726b973)
- `sprites/RSKRA0.png` from `ART SOURCE/SPRITES/PARTICLES/photorealisticspark/spark.png` (sha1 8bd9c613a6460704b7b1b67eb51f5130c044b23e), rotate
- `sprites/RSKTA0.png` from `RS_Main/sprites/combatfx/sparks/RSS1A0.png` (sha1 910c839098963a268b94588e11f714465bc50d10)
- `sprites/RSKPA0.png` from `RS_Main/sprites/combatfx/sparks/RSS0A0.png` (sha1 3c2ebc639e0c77e3ec7942432278f590f58bcb78)
- `sprites/RSKPB0.png` from `RS_Main/sprites/combatfx/sparks/RSS0B0.png` (sha1 3c19128c8940c94f54cfccab0d633443d12b8772)
- `sprites/RSKPC0.png` from `RS_Main/sprites/combatfx/sparks/RSS0C0.png` (sha1 1d0948af5b0f66c19ddf42f1516824a7722ab3a6)
- `sprites/RSKPD0.png` from `RS_Main/sprites/combatfx/sparks/RSS0D0.png` (sha1 665d837f90016af8aec51c860c7feb93a267a22a)
- `sprites/RSKEA0.png` from `RS_Main/sprites/combatfx/sparks/RSS0S0.png` (sha1 8e6dcc59b40c37d754f09fd726572bf1e2a437e5)
- `sprites/RSKEB0.png` from `RS_Main/sprites/combatfx/sparks/RSS4B0.png` (sha1 c314b8b4f74291a79390b674937ac57510979556)
- `sprites/RSKBA0.png` from `ART SOURCE/SPRITES/PARTICLES/photorealisticspark/yellowflare.png` (sha1 cb2fccf98403a8d9f0dfd76ccc3f9e41bfac00ac), shrink

<!-- BEGIN debris landing sounds (tools/import_debris_sounds.py) -->
## Debris landing sounds (sounds/rsb/debris)

Copied unchanged from RS_Main's sound folders (owner-cleared, 2026-09-14). SHA-1 is of the source.

- `sounds/rsb/debris/chips/impact6.wav` from `RS_Main/sounds/combatfx/impact/impact6.wav` (sha1 9a5d01324b8468fac1dfb06b84b7b025a8c67250)
- `sounds/rsb/debris/chips/impact9.mp3` from `RS_Main/sounds/combatfx/impact/impact9.mp3` (sha1 95a780f6421d9f2c7dc1606cd4cf9b1d38586248)
- `sounds/rsb/debris/chips/impact5.wav` from `RS_Main/sounds/combatfx/impact/impact5.wav` (sha1 96a416ed2ce1a06f5503c1f396e1f6829eaed88d)
- `sounds/rsb/debris/rubble/rockhit1.wav` from `RS_Main/sounds/ch/ROCKHIT1.wav` (sha1 782977c0c47147adc49b132ce92dcf0b6f08ce73)
- `sounds/rsb/debris/rubble/dsmothud.ogg` from `RS_Main/sounds/ch/DSMOTHUD.ogg` (sha1 a68eb189efad113845d4c594992107f565bdb3c3)
- `sounds/rsb/debris/metal/dsbounc1.ogg` from `RS_Main/sounds/combatfx/magdrops/DSBOUNC1.ogg` (sha1 6b055c9b8bc83bb7701e8653d659fac727f0b4c1)
- `sounds/rsb/debris/metal/dsbounc2.ogg` from `RS_Main/sounds/combatfx/magdrops/DSBOUNC2.ogg` (sha1 eafb3628f0bae1b3bcdfa0d467b23b1b86e71f80)
- `sounds/rsb/debris/metal/dsbounc3.ogg` from `RS_Main/sounds/combatfx/magdrops/DSBOUNC3.ogg` (sha1 0c8068ea505c55ff3062665042e37ad3f5dea4fb)
- `sounds/rsb/debris/metal/dsbounc4.ogg` from `RS_Main/sounds/combatfx/magdrops/DSBOUNC4.ogg` (sha1 a6e56ce7cbc95bc46730c01cfc1cc69f08299953)
- `sounds/rsb/debris/metal/dsbounc5.ogg` from `RS_Main/sounds/combatfx/magdrops/DSBOUNC5.ogg` (sha1 9348efd7f71a7e196f5b58de0d7df18684963093)
- `sounds/rsb/debris/metal/dsbounc6.ogg` from `RS_Main/sounds/combatfx/magdrops/DSBOUNC6.ogg` (sha1 dc9b43b4abb9c9d5a4cff3ea657e60a454aee9b2)
- `sounds/rsb/debris/metal_big/dsaounc1.ogg` from `RS_Main/sounds/combatfx/magdrops/DSAOUNC1.ogg` (sha1 835a0636e772a2664af395cf9a3034e37eb56c46)
- `sounds/rsb/debris/metal_big/dsaounc2.ogg` from `RS_Main/sounds/combatfx/magdrops/DSAOUNC2.ogg` (sha1 9fac1585f0b7182f4995caa19f961c352b3fefa0)
- `sounds/rsb/debris/metal_big/dsaounc3.ogg` from `RS_Main/sounds/combatfx/magdrops/DSAOUNC3.ogg` (sha1 7a755bf8a37f0137ee8f594de39937442b9e9b0c)
- `sounds/rsb/debris/metal_big/dsaounc4.ogg` from `RS_Main/sounds/combatfx/magdrops/DSAOUNC4` (sha1 bfd0c6f69649602d92e0f7186f611975a027c252)
- `sounds/rsb/debris/metal_big/dsaounc5.ogg` from `RS_Main/sounds/combatfx/magdrops/DSAOUNC5` (sha1 cdde18702fe06bee8666d355135a54cb4c006c4b)
- `sounds/rsb/debris/metal_big/dsaounc6.ogg` from `RS_Main/sounds/combatfx/magdrops/DSAOUNC6` (sha1 88ef54d63809be96c76062385baa243a38ff88c0)
- `sounds/rsb/debris/glass_big/ice_shatter.ogg` from `RS_Main/sounds/combatfx/ice/ice_shatter.ogg` (sha1 efee3a43af103224176de8662783319dc5d88b7d)
- `sounds/rsb/debris/dirt/gbounce.wav` from `RS_Main/sounds/rs_grenade/GBOUNCE` (sha1 cc3cb80881fc1645f523e7da991a83758d82aca7)
- `sounds/rsb/debris/dirt/grnbnce.wav` from `RS_Main/sounds/rs_gh_weapon/gh_grenade/GRNBNCE` (sha1 43a1edd60ca7b474973ea43d1fa377a7c2a52d4b)
- `sounds/rsb/debris/brass_rifle/dsriflc1.ogg` from `RS_Main/sounds/combatfx/casings/DSRIFLC1.ogg` (sha1 011613aefdc09c740bb57b135611fb6a2477e47a)
- `sounds/rsb/debris/brass_rifle/dsriflc2.ogg` from `RS_Main/sounds/combatfx/casings/DSRIFLC2.ogg` (sha1 f71c84eec0db8c1df6e1933e296608c1e52a7a24)
- `sounds/rsb/debris/brass_rifle/dsriflc3.ogg` from `RS_Main/sounds/combatfx/casings/DSRIFLC3.ogg` (sha1 fc334bc28e35418d3f65d21ef873185c5bc01e75)
- `sounds/rsb/debris/brass_rifle/chgncas2.wav` from `RS_Main/sounds/combatfx/casings/CHGNCAS2` (sha1 39ff772e77e2e8f7fe16740449db2e6043eb328d)
<!-- END debris landing sounds -->

<!-- BEGIN gunshot tails (tools/import_tails.py) -->
## Gunshot tails (sounds/rsb/tail)

Copied unchanged from the owner's ART SOURCE library (a permitted asset pool). SHA-1 is of the source.

- `sounds/rsb/tail/pistol/int/weap_pistol_fire_plr_atmo_int1_01.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/pistol/weap_pistol_fire_plr_atmo_int1_01.ogg` (sha1 8a1cb6b9780ae84b7786ba827baf82d8a5329608)
- `sounds/rsb/tail/pistol/int/weap_pistol_fire_plr_atmo_int1_02.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/pistol/weap_pistol_fire_plr_atmo_int1_02.ogg` (sha1 20f586a04fcc7de1d6e1d377e4b56eb12edb236f)
- `sounds/rsb/tail/pistol/int/weap_pistol_fire_plr_atmo_int1_03.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/pistol/weap_pistol_fire_plr_atmo_int1_03.ogg` (sha1 d7db9c6fb1be29d427d156c181285b841f208532)
- `sounds/rsb/tail/pistol/int/weap_pistol_fire_plr_atmo_int1_04.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/pistol/weap_pistol_fire_plr_atmo_int1_04.ogg` (sha1 cd92d1d5db529e9d0f72204c77cc23d4b14116a4)
- `sounds/rsb/tail/pistol/int/weap_pistol_fire_plr_atmo_int1_05.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/pistol/weap_pistol_fire_plr_atmo_int1_05.ogg` (sha1 61f2f94b69442896c29cf99361923b2f6380feac)
- `sounds/rsb/tail/pistol/int/weap_pistol_fire_plr_atmo_int1_06.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/pistol/weap_pistol_fire_plr_atmo_int1_06.ogg` (sha1 e386a7819dd2c475e86bc18908bf2e04adb4bea5)
- `sounds/rsb/tail/pistol/ext/weap_pistol_fire_plr_atmo_ext1_01.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/pistol/weap_pistol_fire_plr_atmo_ext1_01.ogg` (sha1 c6e28ea7d349535d087b9aedc2fb6f60263a02a7)
- `sounds/rsb/tail/pistol/ext/weap_pistol_fire_plr_atmo_ext1_02.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/pistol/weap_pistol_fire_plr_atmo_ext1_02.ogg` (sha1 ece693f1aa3f96f4d503ce28f8730af57bb6b437)
- `sounds/rsb/tail/pistol/ext/weap_pistol_fire_plr_atmo_ext1_03.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/pistol/weap_pistol_fire_plr_atmo_ext1_03.ogg` (sha1 f91d6156286c8625d649539967838364adb1f3e1)
- `sounds/rsb/tail/pistol/ext/weap_pistol_fire_plr_atmo_ext1_04.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/pistol/weap_pistol_fire_plr_atmo_ext1_04.ogg` (sha1 48b50ecb1d91484b81bbe36abe36b77df81a9f17)
- `sounds/rsb/tail/pistol/ext/weap_pistol_fire_plr_atmo_ext1_05.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/pistol/weap_pistol_fire_plr_atmo_ext1_05.ogg` (sha1 1cf8260a02cebcc9c0a28fe9ff2622680a210b5d)
- `sounds/rsb/tail/pistol/ext/weap_pistol_fire_plr_atmo_ext1_06.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/pistol/weap_pistol_fire_plr_atmo_ext1_06.ogg` (sha1 83bf2fdffe13a244803590ae3e23be8798f07d4d)
- `sounds/rsb/tail/pistol_mag/ext/weap_pistol_mag_fire_plr_atmo_ext1_01.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/pistol_mag/weap_pistol_mag_fire_plr_atmo_ext1_01.ogg` (sha1 5709b6ae350f570e995df95d7bce999628ae8672)
- `sounds/rsb/tail/pistol_mag/ext/weap_pistol_mag_fire_plr_atmo_ext1_02.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/pistol_mag/weap_pistol_mag_fire_plr_atmo_ext1_02.ogg` (sha1 5ce9ab71c16db4016ef7c9dedd894226a7723fa6)
- `sounds/rsb/tail/pistol_mag/ext/weap_pistol_mag_fire_plr_atmo_ext1_03.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/pistol_mag/weap_pistol_mag_fire_plr_atmo_ext1_03.ogg` (sha1 b5477086de778ae814e866c43b57e13e4f2d598d)
- `sounds/rsb/tail/pistol_mag/ext/weap_pistol_mag_fire_plr_atmo_ext1_04.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/pistol_mag/weap_pistol_mag_fire_plr_atmo_ext1_04.ogg` (sha1 7aa05e4a2dd31c85245472375b8640c884946969)
- `sounds/rsb/tail/pistol_mag/ext/weap_pistol_mag_fire_plr_atmo_ext1_05.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/pistol_mag/weap_pistol_mag_fire_plr_atmo_ext1_05.ogg` (sha1 4f3bbccdb4048aa8d7986b89250cb41aba9a66db)
- `sounds/rsb/tail/pistol_mag/ext/weap_pistol_mag_fire_plr_atmo_ext1_06.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/pistol_mag/weap_pistol_mag_fire_plr_atmo_ext1_06.ogg` (sha1 9a59d3f8fa57c7e9fefe04a4c0660889f00f42b2)
- `sounds/rsb/tail/shotgun/int/weap_shotgun_fire_plr_atmo_int1_01.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/shotgun/weap_shotgun_fire_plr_atmo_int1_01.ogg` (sha1 a9c7721393ef515fcd0c9fbc79c96c4ee6728ed8)
- `sounds/rsb/tail/shotgun/int/weap_shotgun_fire_plr_atmo_int1_02.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/shotgun/weap_shotgun_fire_plr_atmo_int1_02.ogg` (sha1 6229bca07cc2f86cb1446edab269092ba81cdec1)
- `sounds/rsb/tail/shotgun/int/weap_shotgun_fire_plr_atmo_int1_03.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/shotgun/weap_shotgun_fire_plr_atmo_int1_03.ogg` (sha1 37dc3407ec62f1643e0874f961f5161a79621a84)
- `sounds/rsb/tail/shotgun/int/weap_shotgun_fire_plr_atmo_int1_04.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/shotgun/weap_shotgun_fire_plr_atmo_int1_04.ogg` (sha1 b698907df38c4a98304c7648a022dd414e519973)
- `sounds/rsb/tail/shotgun/int/weap_shotgun_fire_plr_atmo_int1_05.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/shotgun/weap_shotgun_fire_plr_atmo_int1_05.ogg` (sha1 cfc80df210dabd0229ea24fd8fc148e374588cc0)
- `sounds/rsb/tail/shotgun/int/weap_shotgun_fire_plr_atmo_int1_06.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/shotgun/weap_shotgun_fire_plr_atmo_int1_06.ogg` (sha1 5289f960bfa296771b4109db7d86203c0d052a4b)
- `sounds/rsb/tail/shotgun/ext/weap_shotgun_fire_plr_atmo_ext1_01.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/shotgun/weap_shotgun_fire_plr_atmo_ext1_01.ogg` (sha1 7b215bc3b4c31700a9980f65d238db3cd817b92b)
- `sounds/rsb/tail/shotgun/ext/weap_shotgun_fire_plr_atmo_ext1_02.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/shotgun/weap_shotgun_fire_plr_atmo_ext1_02.ogg` (sha1 a53a9d78e4b9058d5a2650baba80014f52b54553)
- `sounds/rsb/tail/shotgun/ext/weap_shotgun_fire_plr_atmo_ext1_03.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/shotgun/weap_shotgun_fire_plr_atmo_ext1_03.ogg` (sha1 3f5e75d483798671e4ad492597a15d8b89a547de)
- `sounds/rsb/tail/shotgun/ext/weap_shotgun_fire_plr_atmo_ext1_04.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/shotgun/weap_shotgun_fire_plr_atmo_ext1_04.ogg` (sha1 82515f749c28bd6dbc211eb5a8e8388f2a9c1da6)
- `sounds/rsb/tail/shotgun/ext/weap_shotgun_fire_plr_atmo_ext1_05.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/shotgun/weap_shotgun_fire_plr_atmo_ext1_05.ogg` (sha1 65b06bea21901cfc11f1cad9b323b4fcb5ccf910)
- `sounds/rsb/tail/shotgun/ext/weap_shotgun_fire_plr_atmo_ext1_06.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/shotgun/weap_shotgun_fire_plr_atmo_ext1_06.ogg` (sha1 5f0dc2b776997c1e65b71018f698ab05de67cfcb)
- `sounds/rsb/tail/dbshotgun/ext/weap_shotgun_fire_plr_atmo_ext2_01.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/dbshotgun/weap_shotgun_fire_plr_atmo_ext2_01.ogg` (sha1 f8b913314e21dd1d0270c4cd9d3b9cf65d25c0f8)
- `sounds/rsb/tail/dbshotgun/ext/weap_shotgun_fire_plr_atmo_ext2_02.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/dbshotgun/weap_shotgun_fire_plr_atmo_ext2_02.ogg` (sha1 f8b9d543a1e3e44b6dde0f41093eb898def4a573)
- `sounds/rsb/tail/dbshotgun/ext/weap_shotgun_fire_plr_atmo_ext2_03.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/dbshotgun/weap_shotgun_fire_plr_atmo_ext2_03.ogg` (sha1 09867bc3b8dec79d69cc836efe110ba43111b533)
- `sounds/rsb/tail/dbshotgun/ext/weap_shotgun_fire_plr_atmo_ext2_04.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/dbshotgun/weap_shotgun_fire_plr_atmo_ext2_04.ogg` (sha1 a9c75d6b250bf2a05c2772f0e1a9481f85d9403a)
- `sounds/rsb/tail/dbshotgun/ext/weap_shotgun_fire_plr_atmo_ext2_05.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/dbshotgun/weap_shotgun_fire_plr_atmo_ext2_05.ogg` (sha1 14aefa0e775715d5512a764af53a2a454fd5d0e6)
- `sounds/rsb/tail/dbshotgun/ext/weap_shotgun_fire_plr_atmo_ext2_06.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/dbshotgun/weap_shotgun_fire_plr_atmo_ext2_06.ogg` (sha1 bdcf70d8fedd59c13fe9a0c96eac333caa070533)
- `sounds/rsb/tail/ar/int/weap_ar_fire_plr_atmo_int1_01.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/ar/weap_ar_fire_plr_atmo_int1_01.ogg` (sha1 13e9d0cc041c0582dcd0bb9a818c46fefb4bed7b)
- `sounds/rsb/tail/ar/int/weap_ar_fire_plr_atmo_int1_02.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/ar/weap_ar_fire_plr_atmo_int1_02.ogg` (sha1 f05bd239e4fe809e809dffaa09976190b6e41e43)
- `sounds/rsb/tail/ar/int/weap_ar_fire_plr_atmo_int1_03.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/ar/weap_ar_fire_plr_atmo_int1_03.ogg` (sha1 560e06f39cbcbcdde7221a2fb4f417bb15d12ed3)
- `sounds/rsb/tail/ar/int/weap_ar_fire_plr_atmo_int1_04.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/ar/weap_ar_fire_plr_atmo_int1_04.ogg` (sha1 a10d9943df4c757cb498039fc77075aec906eb08)
- `sounds/rsb/tail/ar/ext/weap_ar3_fire_plr_atmo_ext1_01.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/ar/weap_ar3_fire_plr_atmo_ext1_01.ogg` (sha1 2de1cbb13719f54fa17dada5bf22c1006e4980e4)
- `sounds/rsb/tail/ar/ext/weap_ar3_fire_plr_atmo_ext1_02.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/ar/weap_ar3_fire_plr_atmo_ext1_02.ogg` (sha1 c204e4fc180023eb6fe2db9d39c4c5fdf2bf7619)
- `sounds/rsb/tail/ar/ext/weap_ar3_fire_plr_atmo_ext1_03.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/ar/weap_ar3_fire_plr_atmo_ext1_03.ogg` (sha1 104ab36202d4af6ab9754681426ee240ae1702d6)
- `sounds/rsb/tail/ar/ext/weap_ar3_fire_plr_atmo_ext1_04.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/ar/weap_ar3_fire_plr_atmo_ext1_04.ogg` (sha1 68879ae6e43edae77ad11209a084cc4a6fb35719)
- `sounds/rsb/tail/ar/ext/weap_ar3_fire_plr_atmo_ext1_05.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/ar/weap_ar3_fire_plr_atmo_ext1_05.ogg` (sha1 7a1e38aad32a08edfed81381ae0a3a4bd98f6ae0)
- `sounds/rsb/tail/ar/ext/weap_ar3_fire_plr_atmo_ext1_06.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/ar/weap_ar3_fire_plr_atmo_ext1_06.ogg` (sha1 151f408b363b1519ccfb8c50d3f87ca27eb8feee)
- `sounds/rsb/tail/lmg/int/weap_lmg_fire_plr_atmo_int1_01.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/lmg/weap_lmg_fire_plr_atmo_int1_01.ogg` (sha1 33789db20f330cc9b1d06c10055ebf0d1849e194)
- `sounds/rsb/tail/lmg/int/weap_lmg_fire_plr_atmo_int1_02.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/lmg/weap_lmg_fire_plr_atmo_int1_02.ogg` (sha1 ff8ac4912799d0463928499dc5a56cecdf7011b4)
- `sounds/rsb/tail/lmg/int/weap_lmg_fire_plr_atmo_int1_03.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/lmg/weap_lmg_fire_plr_atmo_int1_03.ogg` (sha1 4803010660d4ca433ea87622db56fd09df00ba0f)
- `sounds/rsb/tail/lmg/int/weap_lmg_fire_plr_atmo_int1_04.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/lmg/weap_lmg_fire_plr_atmo_int1_04.ogg` (sha1 036b126435c5596ff4e0273218eed68950ddbae7)
- `sounds/rsb/tail/lmg/int/weap_lmg_fire_plr_atmo_int1_05.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/lmg/weap_lmg_fire_plr_atmo_int1_05.ogg` (sha1 d51ae38fdb0375f3e5570e6374acc0b0f972f09c)
- `sounds/rsb/tail/lmg/int/weap_lmg_fire_plr_atmo_int1_06.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/lmg/weap_lmg_fire_plr_atmo_int1_06.ogg` (sha1 359bed0b1e59034f6dc27d00099bab67a81c2ae5)
- `sounds/rsb/tail/lmg/ext/weap_lmg_fire_plr_atmo_ext2_01.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/lmg/weap_lmg_fire_plr_atmo_ext2_01.ogg` (sha1 0a28aae3d327c318fd17046097b029b5ee9a9cc1)
- `sounds/rsb/tail/lmg/ext/weap_lmg_fire_plr_atmo_ext2_02.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/lmg/weap_lmg_fire_plr_atmo_ext2_02.ogg` (sha1 1945ad5e807bb1816a42d1c2755e9840335e163c)
- `sounds/rsb/tail/lmg/ext/weap_lmg_fire_plr_atmo_ext2_03.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/lmg/weap_lmg_fire_plr_atmo_ext2_03.ogg` (sha1 ac8560cf4ecdef97c72d09960937004c68f592f0)
- `sounds/rsb/tail/lmg/ext/weap_lmg_fire_plr_atmo_ext2_04.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/lmg/weap_lmg_fire_plr_atmo_ext2_04.ogg` (sha1 84ed15b22e2dda126f7525606e91ffdce8fe69e4)
- `sounds/rsb/tail/lmg/ext/weap_lmg_fire_plr_atmo_ext2_05.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/lmg/weap_lmg_fire_plr_atmo_ext2_05.ogg` (sha1 274e60e5d47add12da6f8d4689aafc5670a0ce6f)
- `sounds/rsb/tail/lmg/ext/weap_lmg_fire_plr_atmo_ext2_06.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/lmg/weap_lmg_fire_plr_atmo_ext2_06.ogg` (sha1 a96d4cca3d18a1d202648c230677430b3b1247ad)
- `sounds/rsb/tail/br/ext/weap_br3_fire_plr_atmo_ext1_01.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/br/weap_br3_fire_plr_atmo_ext1_01.ogg` (sha1 7bfddde1badd34e431a83623ce976936a0de4f50)
- `sounds/rsb/tail/br/ext/weap_br3_fire_plr_atmo_ext1_02.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/br/weap_br3_fire_plr_atmo_ext1_02.ogg` (sha1 5aadc4adf0ea244626d0401a24135af2e186e369)
- `sounds/rsb/tail/br/ext/weap_br3_fire_plr_atmo_ext1_03.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/br/weap_br3_fire_plr_atmo_ext1_03.ogg` (sha1 085a79cdf0ab02cc88fd58a9c170dc8c3ec737f7)
- `sounds/rsb/tail/br/ext/weap_br3_fire_plr_atmo_ext1_04.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/br/weap_br3_fire_plr_atmo_ext1_04.ogg` (sha1 e3322ec4508434a97f0542f670d1e32589600d74)
- `sounds/rsb/tail/br/ext/weap_br3_fire_plr_atmo_ext1_05.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/br/weap_br3_fire_plr_atmo_ext1_05.ogg` (sha1 bc065f6c47991c19bb11ffac184d6d48135a2b3c)
- `sounds/rsb/tail/br/ext/weap_br3_fire_plr_atmo_ext1_06.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/br/weap_br3_fire_plr_atmo_ext1_06.ogg` (sha1 c69a8697e6e719b3ca2ee121f40a7b16afdf0821)
- `sounds/rsb/tail/br/ext/weap_br3_fire_plr_atmo_ext1_07.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/br/weap_br3_fire_plr_atmo_ext1_07.ogg` (sha1 97888c28934e1c869c9b267d4865f1aa263ba674)
- `sounds/rsb/tail/br/ext/weap_br3_fire_plr_atmo_ext1_08.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/br/weap_br3_fire_plr_atmo_ext1_08.ogg` (sha1 b4481a3c4939e9057e2809eb3548d22fb7ca860b)
- `sounds/rsb/tail/smg/int/weap_smg_fire_plr_atmo_int1_01.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/smg/weap_smg_fire_plr_atmo_int1_01.ogg` (sha1 83ac000e81683addeca5a43a2d1b50af9efdda8e)
- `sounds/rsb/tail/smg/int/weap_smg_fire_plr_atmo_int1_02.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/smg/weap_smg_fire_plr_atmo_int1_02.ogg` (sha1 845d1fd71037cd9c730a9961e14de6c0b76a162d)
- `sounds/rsb/tail/smg/int/weap_smg_fire_plr_atmo_int1_03.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/smg/weap_smg_fire_plr_atmo_int1_03.ogg` (sha1 8ac045c8e9404c0c073b4b5a225504dcd517f5cf)
- `sounds/rsb/tail/smg/int/weap_smg_fire_plr_atmo_int1_04.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/smg/weap_smg_fire_plr_atmo_int1_04.ogg` (sha1 290f1eb4d72a5dfc79a38df32d92b7b06596d6bf)
- `sounds/rsb/tail/smg/int/weap_smg_fire_plr_atmo_int1_05.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/smg/weap_smg_fire_plr_atmo_int1_05.ogg` (sha1 de60f74d33087986a51dd96e26449fdaca6e26dd)
- `sounds/rsb/tail/smg/int/weap_smg_fire_plr_atmo_int1_06.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/int/smg/weap_smg_fire_plr_atmo_int1_06.ogg` (sha1 0df08a2de007a81bf2b8c284dcc450c25e67bf26)
- `sounds/rsb/tail/smg/ext/weap_smg_fire_plr_atmo_ext1_01.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/smg/weap_smg_fire_plr_atmo_ext1_01.ogg` (sha1 9c84931abdcae74267b5558a2f01812b9e6394a0)
- `sounds/rsb/tail/smg/ext/weap_smg_fire_plr_atmo_ext1_02.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/smg/weap_smg_fire_plr_atmo_ext1_02.ogg` (sha1 cf7ef6277fc47ff2e47cca712706da54b2584664)
- `sounds/rsb/tail/smg/ext/weap_smg_fire_plr_atmo_ext1_03.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/smg/weap_smg_fire_plr_atmo_ext1_03.ogg` (sha1 f31d7a205afa67cfbe4fbb629d09afae019f59f4)
- `sounds/rsb/tail/smg/ext/weap_smg_fire_plr_atmo_ext1_04.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/smg/weap_smg_fire_plr_atmo_ext1_04.ogg` (sha1 8f2cfc54f0699ad20bf7bae96e55a02b6efbcf46)
- `sounds/rsb/tail/smg/ext/weap_smg_fire_plr_atmo_ext1_05.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/smg/weap_smg_fire_plr_atmo_ext1_05.ogg` (sha1 aea8224cb8177f83f74975728378dba8eacc74fa)
- `sounds/rsb/tail/smg/ext/weap_smg_fire_plr_atmo_ext1_06.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/ext/smg/weap_smg_fire_plr_atmo_ext1_06.ogg` (sha1 a635096929eb752a70861624613cb8929cccd101)
- `sounds/rsb/tail/rpg/int/rpg_atmo_int_med_1.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/distant/int/rpg/rpg_atmo_int_med_1.ogg` (sha1 f23eb92a3b8be48b3a737d7f62a9a89a65f66655)
- `sounds/rsb/tail/rpg/int/rpg_atmo_int_med_2.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/distant/int/rpg/rpg_atmo_int_med_2.ogg` (sha1 422faa01f83458ba5b94c21ac043dc2108340f15)
- `sounds/rsb/tail/rpg/int/rpg_atmo_int_med_3.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/distant/int/rpg/rpg_atmo_int_med_3.ogg` (sha1 3184f0f9d490c84fd0eb5855a0da0cba9c414932)
- `sounds/rsb/tail/rpg/ext/rpg_atmo_ext_med_1.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/distant/ext/rpg/rpg_atmo_ext_med_1.ogg` (sha1 5c1ca7a9ca6abc24f90b30534b53eedb9ba0d744)
- `sounds/rsb/tail/rpg/ext/rpg_atmo_ext_med_2.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/distant/ext/rpg/rpg_atmo_ext_med_2.ogg` (sha1 a6ba3254ed2e88a061e41b2032ab7554d66f690a)
- `sounds/rsb/tail/rpg/ext/rpg_atmo_ext_med_3.ogg` from `ART SOURCE/SOUNDS/COMBAT/Atmosphere/distant/ext/rpg/rpg_atmo_ext_med_3.ogg` (sha1 ada7f69553f0a1f4230e2f442d104d5555832ad3)
<!-- END gunshot tails -->

<!-- BEGIN surface pass sounds (tools/import_surface_sounds.py) -->
## Surface pass sounds (sounds/rsb/impact_electric, impact_pipe, debris/tile, debris/marble)

Copied unchanged from RS_Main's sound folders and E:/oldshit/ART SOURCE (the owner-cleared pools), or mixed
from them (the pipe hits: ffmpeg, filter in tools/import_surface_sounds.py). SHA-1 is of the source.

- `sounds/rsb/impact_electric/electro8.wav` from `RS_Main/sounds/ch/ELECTRO8.wav` (sha1 40244f51495e3180c4fdbad1a81b0fb5bf950dc3)
- `sounds/rsb/impact_electric/pzaphit.ogg` from `RS_Main/sounds/ch/PZAPHIT.ogg` (sha1 fb793dfb28ecc0fdb3c1e6560b56e70c85419e08)
- `sounds/rsb/impact_electric/dsdevzap.ogg` from `RS_Main/sounds/ch/DSDEVZAP.ogg` (sha1 a8a00acf0d050053559eae094057c1a687c62213)
- `sounds/rsb/impact_electric/electro7.ogg` from `RS_Main/sounds/ch/ELECTRO7.ogg` (sha1 8f9f44c4a4b9c93dfeaadd68e55b5f0bec6beec4)
- `sounds/rsb/impact_electric/sparks1.ogg` from `ART SOURCE/SOUNDS/hbgore/SPARKS1.ogg` (sha1 609e1969ebdc7cf256edc58b8fb5d6f5fb333136)
- `sounds/rsb/debris/tile/tile2_step1.ogg` from `ART SOURCE/SOUNDS/footstep/tilea/tile2_step1.ogg` (sha1 7c464557ab6552a2fa052dea7fbf006c0a496ea2)
- `sounds/rsb/debris/tile/tile2_step2.ogg` from `ART SOURCE/SOUNDS/footstep/tilea/tile2_step2.ogg` (sha1 d8959d0487b69400cc0b17f6d864df61853c8bd6)
- `sounds/rsb/debris/tile/tile2_step3.ogg` from `ART SOURCE/SOUNDS/footstep/tilea/tile2_step3.ogg` (sha1 6d033061e46acfaaaa174581c4a2d2976d0f0080)
- `sounds/rsb/debris/tile/tile2_step4.ogg` from `ART SOURCE/SOUNDS/footstep/tilea/tile2_step4.ogg` (sha1 82380f7edbe673991566bb694c15ad3f9fb9694d)
- `sounds/rsb/debris/tile/dstile01.ogg` from `ART SOURCE/SOUNDS/Doomguy and Marines/DOOMGUY/Sounds/Footsteps sounds/DSTILE01.ogg` (sha1 ab8acdad7a823f1992f3ad5f855a09df71c20848)
- `sounds/rsb/debris/tile/dstile02.ogg` from `ART SOURCE/SOUNDS/Doomguy and Marines/DOOMGUY/Sounds/Footsteps sounds/DSTILE02.ogg` (sha1 9a3fcee56273328bac9a940a4817b0509b0f0f68)
- `sounds/rsb/debris/tile/dstile03.ogg` from `ART SOURCE/SOUNDS/Doomguy and Marines/DOOMGUY/Sounds/Footsteps sounds/DSTILE03.ogg` (sha1 9f1fd7f582d2c207ee4ab352a886b88e565d11ed)
- `sounds/rsb/debris/tile/dstile04.ogg` from `ART SOURCE/SOUNDS/Doomguy and Marines/DOOMGUY/Sounds/Footsteps sounds/DSTILE04.ogg` (sha1 897bd9a0d7206c51b0243735e6b6b0593073fba6)
- `sounds/rsb/debris/tile/dstile05.ogg` from `ART SOURCE/SOUNDS/Doomguy and Marines/DOOMGUY/Sounds/Footsteps sounds/DSTILE05.ogg` (sha1 8ed7c9b16491600a9c70fbe2fd331b2ec5008845)
- `sounds/rsb/debris/tile/dstile06.ogg` from `ART SOURCE/SOUNDS/Doomguy and Marines/DOOMGUY/Sounds/Footsteps sounds/DSTILE06.ogg` (sha1 11bf454efd5e0b358272754d57f9ab6c72246aa5)
- `sounds/rsb/debris/marble/marble_step1.ogg` from `ART SOURCE/SOUNDS/footstep/tileb/marble_step1.ogg` (sha1 36bf29618c112890e46dd6a97093640086b20f3e)
- `sounds/rsb/debris/marble/marble_step2.ogg` from `ART SOURCE/SOUNDS/footstep/tileb/marble_step2.ogg` (sha1 c3004b2789c7248c3a7f2352cbca35250f57347f)
- `sounds/rsb/debris/marble/marble_step3.ogg` from `ART SOURCE/SOUNDS/footstep/tileb/marble_step3.ogg` (sha1 382e547b46db6356a5ee5942121acdf932cbf668)
- `sounds/rsb/debris/marble/marble_step4.ogg` from `ART SOURCE/SOUNDS/footstep/tileb/marble_step4.ogg` (sha1 bc75f708752b3f95fa04642d6d9213a29e35f634)
- `sounds/rsb/debris/marble/marble_step5.ogg` from `ART SOURCE/SOUNDS/footstep/tileb/marble_step5.ogg` (sha1 9b8c5b9b44951b3540a4f40a6ede17c82cbacc0e)
- `sounds/rsb/debris/marble/marble_step6.ogg` from `ART SOURCE/SOUNDS/footstep/tileb/marble_step6.ogg` (sha1 d1ad6ff85e0e0064855ef808d4eb8678da94780e)
- `sounds/rsb/debris/marble/marble_step7.ogg` from `ART SOURCE/SOUNDS/footstep/tileb/marble_step7.ogg` (sha1 94c340cac4f0bfd19b0acbe4583a9aad0aecc07b)
- `sounds/rsb/debris/marble/marble_step8.ogg` from `ART SOURCE/SOUNDS/footstep/tileb/marble_step8.ogg` (sha1 33fcbbffb00d9dcacf9de241d07b62c3bca6495b)
- `sounds/rsb/impact_pipe/pipe_hit1.ogg` mixed by this tool from the package's `sounds/rsb/impact_metal/blt_imp_metal_thick_near_01.ogg` and `ART SOURCE/SOUNDS/COMBAT/WEAPONS/Flamethrower/FlamerHiss2.wav` (sha1 6aa5dce544007ebb93fa91a7dbf62da722d31ef8)
- `sounds/rsb/impact_pipe/pipe_hit2.ogg` mixed by this tool from the package's `sounds/rsb/impact_metal/blt_imp_metal_thick_near_02.ogg` and `ART SOURCE/SOUNDS/COMBAT/WEAPONS/Flamethrower/FlamerHiss1.ogg` (sha1 303883f4b2fcb79fb89b80a989edd39efe124013)
- `sounds/rsb/impact_pipe/pipe_hit3.ogg` mixed by this tool from the package's `sounds/rsb/impact_metal/blt_imp_metal_thick_near_03.ogg` and `ART SOURCE/SOUNDS/COMBAT/WEAPONS/Flamethrower/FlamerHiss2.wav` (sha1 6aa5dce544007ebb93fa91a7dbf62da722d31ef8)
- `sounds/rsb/impact_pipe/pipe_hit4.ogg` mixed by this tool from the package's `sounds/rsb/impact_metal/blt_imp_metal_thick_near_04.ogg` and `ART SOURCE/SOUNDS/COMBAT/WEAPONS/Flamethrower/FlamerHiss1.ogg` (sha1 303883f4b2fcb79fb89b80a989edd39efe124013)
- `sounds/rsb/impact_pipe/pipe_hit5.ogg` mixed by this tool from the package's `sounds/rsb/impact_metal/blt_imp_metal_thick_near_05.ogg` and `ART SOURCE/SOUNDS/COMBAT/WEAPONS/Flamethrower/FlamerHiss2.wav` (sha1 6aa5dce544007ebb93fa91a7dbf62da722d31ef8)
- `sounds/rsb/impact_pipe/pipe_hit6.ogg` mixed by this tool from the package's `sounds/rsb/impact_metal/blt_imp_metal_thick_near_06.ogg` and `ART SOURCE/SOUNDS/COMBAT/WEAPONS/Flamethrower/FlamerHiss1.ogg` (sha1 303883f4b2fcb79fb89b80a989edd39efe124013)
<!-- END surface pass sounds -->

<!-- BEGIN blast sounds (tools/import_blast_sounds.py) -->

- `sounds/rsb/blast/small1.ogg` ffmpeg mono Vorbis q6 from `RS_Main/sounds/combatfx/explosions/PLEXP1` (sha1 d39b7e5f7c838c948622cb5277802436bb5efcca)
- `sounds/rsb/blast/small2.ogg` ffmpeg mono Vorbis q6 from `RS_Main/sounds/combatfx/explosions/PLEXP2` (sha1 51123475789bd16a30a88b252b23291087ea770f)
- `sounds/rsb/blast/small3.ogg` ffmpeg mono Vorbis q6 from `RS_Main/sounds/combatfx/explosions/PLEXP3` (sha1 7dcb469532ed3f3a0f901b0ee65b2a2c4f180ce7)
- `sounds/rsb/blast/med1.ogg` ffmpeg mono Vorbis q6 from `RS_Main/sounds/combatfx/explosions/BA_EXP01.ogg` (sha1 d949f481e8b327460a05be80b7d52377c5d66037)
- `sounds/rsb/blast/med2.ogg` ffmpeg mono Vorbis q6 from `RS_Main/sounds/combatfx/explosions/BA_EXP02` (sha1 226e55f3c9b44121428f8cb4d9b919723d07b366)
- `sounds/rsb/blast/med3.ogg` ffmpeg mono Vorbis q6 from `RS_Main/sounds/combatfx/explosions/BA_EXP03` (sha1 021bd201f64864d85254c4702bdca9c8133a9f0c)
- `sounds/rsb/blast/med4.ogg` ffmpeg mono Vorbis q6 from `RS_Main/sounds/combatfx/explosions/REXP01.ogg` (sha1 074ce5fa12f9f36e06bb887530bc0fdf1f73e3f0)
- `sounds/rsb/blast/med5.ogg` ffmpeg mono Vorbis q6 from `RS_Main/sounds/combatfx/explosions/REXP02.ogg` (sha1 6cf8c128eda334ef6a0edfb324050f0206df6548)
- `sounds/rsb/blast/big1.ogg` ffmpeg mono Vorbis q6 from `RS_Main/sounds/combatfx/explosions/Explode1.wav` (sha1 a52be8651ca7477886603305a8f7e2a6ef5f920f)
- `sounds/rsb/blast/big2.ogg` ffmpeg mono Vorbis q6 from `RS_Main/sounds/combatfx/explosions/Explode2.wav` (sha1 54d1185d154070d5a51e4fad53fdf9511b2c6f0d)
- `sounds/rsb/blast/big3.ogg` ffmpeg mono Vorbis q6 from `RS_Main/sounds/combatfx/explosions/RLANEXPL` (sha1 0b4c1796703272b912068fe601d24a642fe640ab)
- `sounds/rsb/blast/roll1.ogg` ffmpeg mono Vorbis q6 with 180 ms of silence at the head from `RS_Main/sounds/combatfx/explosions/DISTEXP1` (sha1 ede4d2cbc01536ea183755a9da470ca130a3a77b)
- `sounds/rsb/blast/roll2.ogg` ffmpeg mono Vorbis q6 with 180 ms of silence at the head from `RS_Main/sounds/combatfx/explosions/DISTEXP3` (sha1 bbdbc29b8d5234def026bd7ed75888d4c5cea9f2)
- `sounds/rsb/blast/roll3.ogg` ffmpeg mono Vorbis q6 with 180 ms of silence at the head from `RS_Main/sounds/combatfx/explosions/DISTEXP5` (sha1 dd67f5be4e756f611c92f19e494945fd78c03331)

<!-- END blast sounds -->

<!-- BEGIN smoke books (tools/import_smoke_books.py) -->

- `sprites/RSSKA0.png` from `RS_Main/sprites/combatfx/smoke/RSK0A0.png`, padded onto a 142x142 canvas (sha1 6d78bd4fdd0e226a35a03b7b53969617a162e293)
- `sprites/RSSKB0.png` from `RS_Main/sprites/combatfx/smoke/RSK0B0.png`, padded onto a 142x142 canvas (sha1 05b0789d046687111ac4363f2559a18719a4ecb1)
- `sprites/RSSKC0.png` from `RS_Main/sprites/combatfx/smoke/RSK0C0.png`, padded onto a 142x142 canvas (sha1 c5151d1a4bdf6e5f41f5c56c89e23470bc2c9d61)
- `sprites/RSSKD0.png` from `RS_Main/sprites/combatfx/smoke/RSK0D0.png`, padded onto a 142x142 canvas (sha1 9fdd06d362a78de47f40683c45afba3c3896f501)
- `sprites/RSSKE0.png` from `RS_Main/sprites/combatfx/smoke/RSK0E0.png`, padded onto a 142x142 canvas (sha1 9c0cfb03b3a5653b78e80b1eb16fc8f689d49b86)
- `sprites/RSSKF0.png` from `RS_Main/sprites/combatfx/smoke/RSK0F0.png`, padded onto a 142x142 canvas (sha1 35e3375a06178f870bf0cfdfea1afac66a4d5f08)
- `sprites/RSSKG0.png` from `RS_Main/sprites/combatfx/smoke/RSK0G0.png`, padded onto a 142x142 canvas (sha1 2f2f7543b0e23b5715988de8e27fd4482e6b0cec)
- `sprites/RSSKH0.png` from `RS_Main/sprites/combatfx/smoke/RSK0H0.png`, padded onto a 142x142 canvas (sha1 fb2c9f57351a1d1f87d35c300188e48f8cc2bc5c)
- `sprites/RSSKI0.png` from `RS_Main/sprites/combatfx/smoke/RSK0I0.png`, padded onto a 142x142 canvas (sha1 eadd8efa481cc54696e6227a1cbf6bcce58f45d6)
- `sprites/RSSKJ0.png` from `RS_Main/sprites/combatfx/smoke/RSK0J0.png`, padded onto a 142x142 canvas (sha1 3b7707ca42a6587947e45b4269406fa7fb2ef526)
- `sprites/RSSKK0.png` from `RS_Main/sprites/combatfx/smoke/RSK0K0.png`, padded onto a 142x142 canvas (sha1 e2f8fba810b38ad26c06e87877564c34e56f930c)
- `sprites/RSSKL0.png` from `RS_Main/sprites/combatfx/smoke/RSK0L0.png`, padded onto a 142x142 canvas (sha1 1ab322da495aaab2d7cd0ad88bfc16b305665fd3)
- `sprites/RSSKM0.png` from `RS_Main/sprites/combatfx/smoke/RSK0M0.png`, padded onto a 142x142 canvas (sha1 cb850054a70178eed69ce28da66a70b891c87e54)
- `sprites/RSSKN0.png` from `RS_Main/sprites/combatfx/smoke/RSK0N0.png`, padded onto a 142x142 canvas (sha1 8394e4ba8b38951cec940db77a2048843c5ee928)
- `sprites/RSSKO0.png` from `RS_Main/sprites/combatfx/smoke/RSK0O0.png`, padded onto a 142x142 canvas (sha1 9a82f6061f353d68fcdcc64a8a6868684e0e0393)
- `sprites/RSSKP0.png` from `RS_Main/sprites/combatfx/smoke/RSK0P0.png`, padded onto a 142x142 canvas (sha1 9638d2312694d5d952644daf100fa8127d479ef6)
- `sprites/RSSKQ0.png` from `RS_Main/sprites/combatfx/smoke/RSK0Q0.png`, padded onto a 142x142 canvas (sha1 80277105c125c402db62a6d392e1bb6df6ba0c1f)
- `sprites/RSSGA0.png` from `RS_Main/sprites/combatfx/smoke/RSK4A0.png`, padded onto a 100x100 canvas (sha1 243f14b398abf86200766e399e60c1db29d7a1e9)
- `sprites/RSSGB0.png` from `RS_Main/sprites/combatfx/smoke/RSK4B0.png`, padded onto a 100x100 canvas (sha1 cba99aefa3f9fe63e83825214eae762a02b8bd73)
- `sprites/RSSGC0.png` from `RS_Main/sprites/combatfx/smoke/RSK4C0.png`, padded onto a 100x100 canvas (sha1 8389be424343f58a21fd47f3b8c2ad88a0942652)
- `sprites/RSSGD0.png` from `RS_Main/sprites/combatfx/smoke/RSK4D0.png`, padded onto a 100x100 canvas (sha1 70db3695c0050c612bb9ea97cf7b6a234615ed88)
- `sprites/RSSGE0.png` from `RS_Main/sprites/combatfx/smoke/RSK4E0.png`, padded onto a 100x100 canvas (sha1 97ceb94b55f31ae1af0c4f78ebfb47fb3f3058e6)
- `sprites/RSSGF0.png` from `RS_Main/sprites/combatfx/smoke/RSK4F0.png`, padded onto a 100x100 canvas (sha1 0f559c48ac9c5972326b82adc677d141cc69a0d7)
- `sprites/RSSGG0.png` from `RS_Main/sprites/combatfx/smoke/RSK4G0.png`, padded onto a 100x100 canvas (sha1 4ec58a5f72daf4d5a20f6127365bebbaff0ed7cf)
- `sprites/RSSGH0.png` from `RS_Main/sprites/combatfx/smoke/RSK4H0.png`, padded onto a 100x100 canvas (sha1 e9a579d8743e62b873d0c07c60d7bf3842c40930)
- `sprites/RSSGI0.png` from `RS_Main/sprites/combatfx/smoke/RSK4I0.png`, padded onto a 100x100 canvas (sha1 145f2e563142130e51a022e27bcc5825ea8c0776)
- `sprites/RSSGJ0.png` from `RS_Main/sprites/combatfx/smoke/RSK4J0.png`, padded onto a 100x100 canvas (sha1 f18ce2fd10487b2769701389b0cd36085b816a2c)
- `sprites/RSSGK0.png` from `RS_Main/sprites/combatfx/smoke/RSK4K0.png`, padded onto a 100x100 canvas (sha1 bc14619033274d3cce80c2ef222301f05d48b73c)
- `sprites/RSSGL0.png` from `RS_Main/sprites/combatfx/smoke/RSK4L0.png`, padded onto a 100x100 canvas (sha1 714f8278c6409b5ef185cbc88a71cb2c120f309d)
- `sprites/RSSGM0.png` from `RS_Main/sprites/combatfx/smoke/RSK4M0.png`, padded onto a 100x100 canvas (sha1 4c2cb80bb39235dca38a3561a444f4148408169a)
- `sprites/RSSGN0.png` from `RS_Main/sprites/combatfx/smoke/RSK4N0.png`, padded onto a 100x100 canvas (sha1 e366a85575996169a86822bd31ced2059ae829e0)
- `sprites/RSSGO0.png` from `RS_Main/sprites/combatfx/smoke/RSK4O0.png`, padded onto a 100x100 canvas (sha1 4b8c040713405a1797610235b39b4267cd656ac5)
- `sprites/RSSGP0.png` from `RS_Main/sprites/combatfx/smoke/RSK4P0.png`, padded onto a 100x100 canvas (sha1 e43af293bb204aa754fc2532baa2306b10ce1186)
- `sprites/RSSGQ0.png` from `RS_Main/sprites/combatfx/smoke/RSK4Q0.png`, padded onto a 100x100 canvas (sha1 a74c269f17968a0af6d0403af86f036375e2eee5)
- `sprites/RSSGR0.png` from `RS_Main/sprites/combatfx/smoke/RSK4R0.png`, padded onto a 100x100 canvas (sha1 36a8f8d9d82e3b656feb16d2c4dacfc680e6022f)
- `sprites/RSSGS0.png` from `RS_Main/sprites/combatfx/smoke/RSK4S0.png`, padded onto a 100x100 canvas (sha1 b81403716d98fef48878ecd6f4007f92a9d71c05)
- `sprites/RSSGT0.png` from `RS_Main/sprites/combatfx/smoke/RSK4T0.png`, padded onto a 100x100 canvas (sha1 d966d2985ddf0fea2ee964e21b40d3a4799db493)
- `sprites/RSSGU0.png` from `RS_Main/sprites/combatfx/smoke/RSK4U0.png`, padded onto a 100x100 canvas (sha1 0b42e4c180fb6a28f88abfdb44ed06688ff33540)
- `sprites/RSSGV0.png` from `RS_Main/sprites/combatfx/smoke/RSK4V0.png`, padded onto a 100x100 canvas (sha1 6523013a1d4890113caf3f97ed4ab81fa6fd2c2d)
- `sprites/RSSGW0.png` from `RS_Main/sprites/combatfx/smoke/RSK4W0.png`, padded onto a 100x100 canvas (sha1 9f460f17119d61d8f52d9c24397dfc68cb62ad3d)
- `sprites/RSSWA0.png` from `RS_Main/sprites/combatfx/smoke/RSK5A0.png`, padded onto a 128x128 canvas (sha1 6f0c3bc65bfb5c96c4800be412578cc5d411068a)
- `sprites/RSSWB0.png` from `RS_Main/sprites/combatfx/smoke/RSK5B0.png`, padded onto a 128x128 canvas (sha1 55d95c8b4dcb7e1dc5c2ed392a1db74f36b70a17)
- `sprites/RSSWC0.png` from `RS_Main/sprites/combatfx/smoke/RSK5C0.png`, padded onto a 128x128 canvas (sha1 0f64631d70a6a141d483b3b467d729df8fd371e4)
- `sprites/RSSWD0.png` from `RS_Main/sprites/combatfx/smoke/RSK5D0.png`, padded onto a 128x128 canvas (sha1 359cabe18aa95d5806ec226c109bfa5144fdfecc)
- `sprites/RSSWE0.png` from `RS_Main/sprites/combatfx/smoke/RSK5E0.png`, padded onto a 128x128 canvas (sha1 d1d284f5dc4e22a46a5f0837a205efb8d1df9ab4)
- `sprites/RSSWF0.png` from `RS_Main/sprites/combatfx/smoke/RSK5F0.png`, padded onto a 128x128 canvas (sha1 bdbaffbfe4b129cf4f37825f1c4df66a195bbbe4)
- `sprites/RSSWG0.png` from `RS_Main/sprites/combatfx/smoke/RSK5G0.png`, padded onto a 128x128 canvas (sha1 5b05970df1547c0158b5d7b7c24b4bf2e0775913)
- `sprites/RSSWH0.png` from `RS_Main/sprites/combatfx/smoke/RSK5H0.png`, padded onto a 128x128 canvas (sha1 a0d2bc0e4dae58a95bb3fa4d874e735ad6f73062)

<!-- END smoke books -->
