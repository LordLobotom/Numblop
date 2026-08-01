# Didaktický algoritmus hry – MVP

## 1. Učení násobilek

Násobilky se učí postupně:

> 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9

Každá násobilka obsahuje 10 spojů:

- ×0
- ×1
- ×2
- ×3
- ×4
- ×5
- ×6
- ×7
- ×8
- ×9

Každý spoj má vlastní hodnotu zvládnutí v rozsahu **0–100 bodů**.

---

## 2. Odemčení další násobilky

Další násobilka se odemkne ve chvíli, kdy všech 10 spojů aktuální násobilky dosáhne alespoň hodnoty **80**.

Tím je zajištěno, že dítě zvládá celou násobilku, nikoliv pouze některé spoje.

---

## 3. Automatizace

Po odemčení další násobilky se starší spoje nepřestanou procvičovat.

Rozlišujeme dvě hranice:

- **80 bodů** – spoj je dostatečně zvládnutý pro pokračování.
- **90 bodů** – spoj je považován za automatizovaný.

Automatizované spoje se stále občas objevují, aby se upevnily v dlouhodobé paměti.

---

## 4. Typ úlohy podle zvládnutí

| Hodnota spoje | Typ úlohy |
|---|---|
| 0–59 | Výběr ze 4 možností |
| 60–89 | Výběr ze 6 možností |
| 90–100 | Zadání výsledku z klávesnice |

Použití přesných hranic 0–59, 60–89 a 90–100 zabraňuje nejasnostem při implementaci.

---

## 5. Jedna hra

Jedna hra obsahuje **10 úloh**:

- **7 úloh** z aktuálně učené násobilky,
- **2 úlohy** ze starších spojů s hodnotou pod 90,
- **1 úlohu** z již automatizovaných spojů s hodnotou 90 a více.

### Výběr konkrétního spoje

V rámci každé skupiny mají přednost spoje s nejnižší hodnotou zvládnutí.

Pokud má více spojů stejnou hodnotu, vybírají se náhodně.

---

## 6. Vyhodnocení odpovědi

Každá odpověď se hodnotí podle:

- správnosti,
- rychlosti.

### Změna hodnoty spoje

| Výsledek | Změna |
|---|---:|
| Správně a rychle | +5 |
| Správně, ale pomaleji | +3 |
| Špatně | −2 |

Po změně se hodnota vždy omezí na rozsah **0–100**.

---

## 7. Limity pro rychlou odpověď

| Typ úlohy | Rychlá odpověď |
|---|---:|
| Výběr ze 4 možností | do 2,5 s |
| Výběr ze 6 možností | do 3 s |
| Zadání výsledku | do 4 s |

Odpověď po překročení limitu je stále správná, ale započítává se jako správná pomalá odpověď.

---

## 8. Návrat mezi jednodušší úlohy

Pokud dítě začne dělat chyby, spoj se automaticky vrací na jednodušší typ procvičování.

- Pokles pod **90**
  → místo zadání výsledku se opět používá výběr odpovědi.

- Pokles pod **60**
  → spoj se vrací na výběr ze 4 možností.

- Pokles pod **80**
  → spoj se znovu zařazuje mezi běžně procvičované spoje.

Jedna chyba nesmí výrazně ovlivnit dlouhodobé zvládnutí spoje. Opakované chyby však hodnotu postupně snižují.

---

## 9. Priorita procvičování

Při výběru další úlohy platí:

1. Spoje s nejnižší hodnotou mají nejvyšší prioritu.
2. Spoje pod 80 se objevují nejčastěji.
3. Spoje v rozsahu 80–89 se objevují méně často.
4. Spoje s hodnotou 90 a více se objevují pouze občas jako kontrolní opakování.

---

## Schéma algoritmu

```text
              Začátek hry
                    │
                    ▼
        Vyber spoj podle priority
                    │
                    ▼
      Urči typ úlohy podle hodnoty

      0–59  → 4 možnosti
      60–89 → 6 možností
      90+   → psaní výsledku

                    │
                    ▼
          Dítě odpoví na příklad
                    │
        ┌───────────┴───────────┐
        │                       │
     Správně                 Špatně
        │                       │
        ▼                       ▼
 Změří se čas                −2 body
        │
   ┌────┴────┐
   │         │
Rychle   Pomaleji
   │         │
 +5        +3
   │         │
   └────┬────┘
        ▼
 Aktualizace hodnoty (0–100)
        │
        ▼
 Změna typu úlohy podle nové hodnoty
        │
        ▼
 Všech 10 spojů ≥ 80?
        │
    Ano │ Ne
        │
        ▼
 Odemkni další násobilku
```

---

## Poznámka k MVP

Lineární změna hodnoty spoje pomocí `+5`, `+3` a `−2` je pro první verzi vhodná, protože je jednoduchá, předvídatelná a snadno implementovatelná.

V budoucnu lze algoritmus rozšířit například o:

- zpomalování postupu při vyšší hodnotě zvládnutí,
- zohlednění série správných nebo chybných odpovědí,
- časový rozestup od posledního procvičení,
- adaptivní limity podle konkrétního dítěte,
- rozložené opakování.

---

## Potvrzená implementační rozhodnutí

Tato pravidla jsou součástí MVP a odstraňují nejasnosti při implementaci:

- Jednou odemčená násobilka se již nikdy znovu nezamkne, ani když hodnota staršího spoje
  později klesne pod 80.
- Pokud pro skupinu opakovacích úloh není dost vhodných spojů, chybějící místa se doplní
  spoji z aktuálně učené násobilky. Jedna hra má vždy 10 úloh.
- Stejný spoj se nesmí objevit ve dvou bezprostředně po sobě jdoucích úlohách.
- Čas odpovědi se měří pro výpočet změny zvládnutí, ale dítě během odpovídání nevidí
  stresující odpočet.
- V MVP se spoje `a × b` a `b × a` evidují podle příslušné násobilky samostatně.
