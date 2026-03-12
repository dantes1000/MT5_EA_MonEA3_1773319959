```markdown
# MonEA3 - Expert Advisor pour MetaTrader 5

## Description
MonEA3 est un Expert Advisor (EA) avancé pour MetaTrader 5, implémentant une stratégie de **Range Breakout** sur la session asiatique. L'EA identifie les niveaux de support et résistance établis pendant la session asiatique (00:00-06:00 GMT) et place des ordres pending pour capturer les mouvements directionnels lors de l'ouverture des marchés européens.

**Stratégie clé** : "Asian Session Range Breakout" avec filtres stricts de tendance, volume, volatilité et actualités économiques.

## Caractéristiques principales
- **Logique de trading** : Breakout bidirectionnel (Long/Short) d'un range défini sur D1
- **Filtres intégrés** : EMA200 H1, ATR, Bollinger Bands, ADX, Volume et actualités économiques
- **Gestion des risques** : Drawdown quotidien/total limité, risque par trade configurable
- **Protections** : Filtre news automatique (FFCal), fermeture weekend, limites de trades
- **Execution** : Ordres pending Buy Stop/Sell Stop avec gestion de slippage et retry

## Prérequis
- **Plateforme** : MetaTrader 5 (build 2000+ recommandé)
- **Broker** : Compte de trading avec exécution rapide (ECN/RAW spread recommandé)
- **Indicateur requis** : `FFCal.ex5` (Calendrier économique) doit être installé dans `MQL5/Indicators/`
- **Paires** : Majeures recommandées (EURUSD, GBPUSD, USDJPY)
- **Timeframes** : D1 (analyse) + M15/M30 (exécution) + H1 (filtre tendance)

## Installation
1. **Télécharger les fichiers** :
   - `MonEA3.ex5` (EA compilé)
   - `MonEA3.mq5` (code source, si fourni)
   - Fichiers include (`*.mqh`) dans `MQL5/Include/`

2. **Copier dans MetaTrader 5** :
   - Placer `MonEA3.ex5` dans le dossier : `[MT5 Data Folder]/MQL5/Experts/`
   - Placer les fichiers include dans : `[MT5 Data Folder]/MQL5/Include/`
   - Placer `FFCal.ex5` dans : `[MT5 Data Folder]/MQL5/Indicators/`

3. **Redémarrer MT5** ou actualiser le Navigateur

4. **Attacher l'EA** :
   - Ouvrir un graphique EURUSD D1
   - Glisser-déposer `MonEA3` depuis le Navigateur
   - Configurer les paramètres (voir ci-dessous)
   - Activer "Auto Trading" (bouton ON vert)

## Paramètres configurables

### 1. Breakout / Cassure
| Paramètre | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `BreakoutType` | 0 | Type de cassure : 0=Range, 1=BollingerBands, 2=ATR |
| `AllowLong` | true | Autoriser les positions longues |
| `AllowShort` | true | Autoriser les positions courtes |
| `RequireVolumeConfirm` | true | Exiger confirmation du volume (>1.5x moyenne) |
| `RequireRetest` | false | Attendre un retest avant entrée |
| `RangeTF` | PERIOD_D1 | Timeframe pour calcul du range |
| `TrendFilterEMA` | 200 | Période EMA pour filtre tendance (0=désactivé) |
| `ExecTF` | PERIOD_M15 | Timeframe pour exécution des trades |

### 2. Filtre News
| Paramètre | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `UseNewsFilter` | true | Activer le filtre d'actualités économiques |
| `NewsMinutesBefore` | 60 | Minutes avant news pour suspendre trading |
| `NewsMinutesAfter` | 30 | Minutes après news pour reprendre trading |
| `NewsImpactLevel` | 3 | Niveau d'impact minimum : 1=faible, 2=moyen, 3=fort |
| `CloseOnHighImpact` | true | Fermer positions avant news à fort impact |

### 3. Filtres Indicateurs
| Paramètre | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `UseATRFilter` | true | Activer filtre ATR (volatilité) |
| `ATRPeriod` | 14 | Période ATR |
| `MinATRPips` | 20 | ATR minimum requis (pips) |
| `MaxATRPips` | 150 | ATR maximum autorisé (pips) |
| `UseBBFilter` | true | Activer filtre Bollinger Bands |
| `BBPeriod` | 20 | Période Bollinger Bands |
| `Min_Width_Pips` | 30 | Largeur BB minimum (pips) |
| `Max_Width_Pips` | 120 | Largeur BB maximum (pips) |
| `UseEMAFilter` | true | Activer filtre EMA tendance |
| `EMATf` | PERIOD_H1 | Timeframe EMA |
| `UseADXFilter` | true | Activer filtre ADX (force tendance) |
| `ADXThreshold` | 20.0 | Seuil ADX minimum |
| `UseVolumeFilter` | true | Activer filtre volume |

### 4. Gestion des Positions
| Paramètre | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `MagicNumber` | 123456 | Identifiant unique des ordres |
| `MaxSlippage` | 3 | Slippage maximum (points) |
| `MaxOrderRetries` | 3 | Tentatives max d'envoi d'ordre |
| `UsePartialClose` | false | Activer fermeture partielle |
| `AllowAddPosition` | false | Autoriser ajout de position |

### 5. Gestion des Risques
| Paramètre | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `LotMethod` | 0 | 0=% capital, 1=lot fixe, 2=lot par pip |
| `RiskPercent` | 1.0 | % du capital risqué par trade |
| `MinLot` | 0.01 | Lot minimum |
| `MaxLot` | 5.0 | Lot maximum |
| `TP_Method` | 1 | 0=Fixe (RR), 1=Dynamique_ATR |
| `ATR_TP_Mult` | 3 | Multiplicateur ATR pour TP dynamique |
| `MaxDailyDDPercent` | 5.0 | Drawdown quotidien max (%) |
| `MaxTotalDDPercent` | 10.0 | Drawdown total max (%) |
| `MaxOpenTrades` | 1 | Positions simultanées max |
| `MaxTradesPerDay` | 3 | Trades par jour max |
| `MinTimeBetweenTrades` | 1 | Délai minimum entre trades (heures) |

### 6. Range de Prix
| Paramètre | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `RangePeriodHours` | 6 | Durée du range (0-6h GMT) |
| `MarginPips` | 5 | Marge au-delà du High/Low (pips) |
| `MinRangePips` | 30 | Range minimum valide (pips) |
| `MaxRangePips` | 120 | Range maximum autorisé (pips) |

### 7. Filtres Temporels
| Paramètre | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `TradeStartHour` | 8 | Heure début trading (GMT, ouverture London) |
| `TradeEndHour` | 23 | Heure fin trading (GMT) |
| `WeekendClose` | true | Fermer positions avant weekend |
| `FridayCloseHour` | 21 | Heure fermeture vendredi (GMT) |

### 8. Tendance & Trailing
| Paramètre | Valeur par défaut | Description |
|-----------|-------------------|-------------|
| `TrendEMAPeriod` | 200 | Période EMA tendance globale |
| `UseTrailingStop` | true | Activer trailing stop |
| `Trail_Method` | 1 | 0=Fixe, 1=ATR |
| `Trail_Mult` | 0.5 | Multiplicateur ATR pour trailing |
| `Trail_Activation_PC` | 50 | % profit pour activer trailing |

## Utilisation

### Configuration recommandée
1. **Graphique** : Attacher l'EA sur **EURUSD D1**
2. **Timeframes** : L'EA utilise automatiquement D1, H1 et M15
3. **Heures de trading** : 08:00 - 23:00 GMT (optimisé pour sessions London/NY)
4. **Capital initial** : Minimum 1000 USD pour gestion de risque 1%

### Démarrage
1. **Backtest** : Tester sur 2+ années de données tick
2. **Forward test** : 1 mois en démo avant live
3. **Live trading** : Commencer avec 0.5% risk, surveiller drawdown

### Monitoring
- **Journal** : Vérifier les logs dans l'onglet Experts
- **Performances** : Suivre dans l'onglet Historique des Comptes
- **Actualités** : S'assurer que FFCal est à jour

## Logique de Trading

### Entrée
1. **Calcul du range** : High/Low exacts de 00:00-06:00 GMT sur D1
2. **Validation** : Range 30-120 pips, ATR 20-150 pips, volume >1.5x moyenne
3. **Filtre tendance** : Prix > EMA200 H1 pour long, < pour short + ADX >20
4. **Placement ordres** : Buy Stop/Sell Stop à High/Low + 5 pips marge
5. **Temps** : Ordres placés après 08:00 GMT uniquement

### Sortie
- **Stop Loss** : Niveau opposé du range
- **Take Profit** : Dynamique (3x ATR) par défaut, ou fixe (RR 1.5)
- **Trailing Stop** : Activé à 50% profit, basé sur 0.5x ATR

### Protection
- **Annulation** : Ordres pending annulés si breakout avant 08:00 GMT
- **News** : Pas de trading 60min avant / 30min après news fort impact
- **Weekend** : Fermeture automatique vendredi 21:00 GMT
- **Drawdown** : Arrêt si >5% quotidien ou >10% total

## Avertissements sur les Risques

### ⚠️ IMPORTANT
- **Le trading sur marge comporte un risque élevé de perte**
- **Ne tradez pas avec de l'argent que vous ne pouvez pas vous permettre de perdre**
- **Les performances passées ne garantissent pas les résultats futurs**

### Risques spécifiques
1. **Slippage** : Possible pendant news ou volatilité élevée
2. **Gap** : Risque de gap au-dessus du Stop Loss
3. **News imprévues** : Événements non listés dans FFCal
4. **Problèmes techniques** : Connexion internet, serveur broker

### Recommandations
- **Test exhaustif** en démo avant utilisation réelle
- **Surveillance active** même avec EA automatisé
- **Adaptation** des paramètres à votre profil de risque
- **Backup** régulier des paramètres et résultats

## Support
Pour toute question technique :
- Consulter les logs dans MetaTrader 5
- Vérifier la configuration des paramètres
- S'assurer que tous les indicateurs requis sont installés

---

*MonEA3 est un outil d'aide à la décision. Le trader reste seul responsable de ses décisions de trading et de leur exécution.*
```