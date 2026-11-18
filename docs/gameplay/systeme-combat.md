| Traçabilité | |
| --- | --- |
| Document | OKÉLUN — Système de combat et modes de jeu |
| Version | 0.1.0 (source : révision 14) |
| Date | 2026-11-18 (création et dernière révision connues) |
| Statut | Brouillon — conçu et documenté ; non implémenté, non validé |
| Source | Claude Docs « OKÉLUN — Système de combat et modes de jeu », révision 14 ([lien](https://claude.ai/artifact/FFJPMkUML2duUcTwtDrW2R)), export Markdown du 2026-11-18 |
| Documents associés | [Modes de jeu](modes-jeu.md) (§11), [Damage System](../technical/damage-system.md), [Roster](../characters/roster.md), [Architecture technique](../technical/architecture-technique.md) |

> La section 11 de ce document a été déplacée sans modification dans `gameplay/modes-jeu.md`.

<!-- FIN EN-TÊTE DE TRAÇABILITÉ -->

# OKÉLUN — Système de combat et modes de jeu

Nov 18, 2026 · @peut tu modifier une video

Document 3 sur 4. Il définit les règles du combat, son interface et les modes de jeu. Le détail technique des dégâts est dans le GDD technique du Damage Priority & Resolution System ; l'univers et les combattants dans les documents 1 et 2.

## 1. Philosophie du combat

Le combat d'OKÉLUN est un duel 1 contre 1 où chaque coup a une cause physique et une conséquence durable. Il se prend en main avec quatre boutons d'attaque, mais sa profondeur vient de ce que les jeux de combat classiques remettent à zéro : l'équipement, les blessures, la fatigue, l'arène.

### Règles d'or

1. **Simple à comprendre** : quatre attaques, une garde, une esquive. Un joueur novice fait un combat lisible dès la première minute.
2. **Difficile à maîtriser** : cadres de parade, choix de la zone visée, gestion du Souffle, de l'Ancrage et de l'état de l'équipement, lecture de l'arène.
3. **Chaque coup laisse une trace** : aucune touche n'est sans conséquence, même bloquée (usure de la garde, fatigue, recul).
4. **La barre de vie est une abstraction** : elle décide de la victoire, mais l'écran montre toujours ce qui est arrivé au corps et à l'équipement.
5. **Les pouvoirs obéissent à la physique** : une Résonance traverse la même chaîne de dégâts qu'une arme.
6. **Le joueur garde toujours la maîtrise** : aucune conséquence ne dépend du hasard ; une blessure ralentit, elle ne paralyse jamais.

### La chaîne officielle

IMPACT → LOCALISATION → PROTECTION → MATÉRIAU → ABSORPTION → TRANSMISSION → DOMMAGE → BLESSURE → SAIGNEMENT → FATIGUE → CONSÉQUENCE → PERSISTANCE.

C'est la version du cahier des charges « Philosophie du combat », avec FATIGUE comme étape propre. Le GDD technique des dégâts utilise encore une version à 11 étapes ; il devra être aligné (voir l'audit).

### Rythme d'un échange

impact → réaction → récupération → contre → adaptation. Après chaque échange, les deux combattants ne sont plus dans le même état qu'avant : le combat suivant doit s'adapter à ce qui a changé.

## 2. Commandes et actions

Six boutons suffisent à toutes les actions ; la profondeur vient des combinaisons, du timing et de la direction.

### Boutons

| Bouton | Action de base | Avec direction | Maintenu |
| --- | --- | --- | --- |
| Léger | coup rapide, peu de recul | change la hauteur et le côté visés | — |
| Lourd | coup lent, fort transfert de poids | change la zone visée | attaque chargée |
| Technique | coup d'arme spécifique ou technique de corps | variantes propres à chaque combattant | posture (pour certains) |
| Résonance | pouvoir, consomme du Kalé | variantes du pouvoir | version renforcée |
| Garde | bloque | garde haute, basse, latérale | garde tenue |
| Esquive | pas rapide | direction de l'esquive | course |

**Combinaisons fixes** : Léger + Lourd = projection ; Lourd + Technique = attaque contextuelle (si un élément d'arène est à portée) ; Technique + Résonance = capacité spéciale ; les quatre boutons d'attaque = capacité ultime.

Un schéma simplifié (enchaînements automatiques sur un bouton) existe pour l'accessibilité, sans accès aux variantes de visée.

### Familles d'actions

| Famille | Exemples | Ce qui la distingue |
| --- | --- | --- |
| Arts martiaux et corps à corps | coups de poing, de pied, de coude, de genou, d'épaule | toujours disponibles, même sans arme |
| Armes blanches | lames, lances, faux | tranchant ou perforant, portée |
| Armes lourdes | masses, marteaux, bâtons ferrés | lourd ou contondant, recul important |
| Armes improvisées | objets d'arène | intégrité faible, se cassent vite |
| Pouvoirs | Résonances | Kalé, Marques permanentes |
| Esquives | pas, roulades, appuis sur murs | Souffle |
| Parades | garde active au bon moment | ouvre un contre |
| Contres | après parade ou esquive parfaite | punitions |
| Projections | saisie puis projection | contre le sol, un mur, un obstacle : impact environnemental |
| Prises | saisies maintenues, étranglements, clés | usent le Souffle des deux combattants |
| Attaques aériennes | coups en saut, rebonds | Ancrage nul pendant le saut |
| Attaques chargées | Lourd maintenu | plus de force, fenêtre d'interruption |
| Combos | enchaînements de coups | limités par le Souffle et l'Ancrage adverse |
| Attaques contextuelles | utiliser un mur, une colonne, un étal | modifient l'arène de façon persistante |
| Finishers | fin de combat | cinématiques, cohérents avec l'état réel |
| Capacités ultimes | une par combattant | séquence cinématique courte |

### Combos

- Chaque combattant a des enchaînements fixes (« cordes ») et des liaisons libres basées sur le timing.
- Les combos sont limités physiquement : un adversaire projeté trop loin sort de portée, un adversaire bien ancré ne recule pas, un attaquant sans Souffle ralentit.
- Pas de « jonglage » infini : un corps en l'air retombe selon la gravité réelle.

## 3. Ressources et interface

L'interface affiche cinq informations seulement : santé, énergie (Souffle), jauge spéciale (Kalé), statut et timer. Tout le reste se lit sur le corps.

| Ressource | Affichage | Monte | Descend | Ce qu'elle décide |
| --- | --- | --- | --- | --- |
| Santé | barre en haut | jamais en combat, sauf mécanique explicite | coups reçus (plafonné par coup) | la défaite à zéro |
| Souffle (énergie) | barre fine sous la santé | au repos relatif, plus lentement si fatigué | actions, esquives, prises, parades ratées | vitesse et nombre d'actions enchaînables |
| Kalé (jauge spéciale) | jauge en bas, trois segments | coups portés, coups encaissés, parades réussies | Résonance, spéciales, ultime | accès aux pouvoirs |
| Ancrage (équilibre) | aucun affichage ; lu sur la posture | se rétablit en quelques secondes | coups reçus, Vent, terrain glissant | déséquilibre, chute |
| Fatigue | aucun affichage ; lue sur la respiration, la sueur, la posture | effort, chocs, perte de sang | repos uniquement (entre les combats) | plafond du Souffle et vitesse de récupération |

### Statut

Une seule icône de statut à la fois, la plus importante : saignement important, pièce critique, arme en danger, membre affaibli, statut élémentaire. Elle s'efface quand le corps le montre assez clairement.

### Timer

99 secondes par manche en compétitif ; pas de timer en Histoire, Exploration et Training. À la fin du temps, c'est la santé restante qui décide, puis l'état des pièces critiques.

## 4. Physique des corps

Les corps ont un poids réel : un coup puissant déplace, un combattant lourd encaisse autrement qu'un léger, et personne ne glisse sur le sol.

### Classes de poids

| Classe | Poids | Exemples | Vitesse | Recul subi | Ancrage |
| --- | --- | --- | --- | --- | --- |
| Léger | moins de 60 kg | Amisé, Lissawé, Ilèka | très rapide | fort | faible |
| Moyen | 60 à 85 kg | Okwaa, Namoré, Yéwaro | équilibrée | moyen | moyen |
| Lourd | 85 à 110 kg | Tandé, Mabé, Tchalo, Ondéla | lente | faible | fort |
| Très lourd | plus de 110 kg | Bassù | très lente | très faible | très fort |

Le poids réel de chaque combattant (fiches du document 2) est utilisé tel quel dans les calculs ; les classes servent à la lecture et à l'équilibrage.

### Règles physiques

- **Gravité et inertie** : un corps en mouvement continue ; un changement de direction coûte du temps, plus pour les lourds.
- **Centre de gravité** : calculé en continu à partir du squelette ; s'il sort de la base d'appui, le combattant perd l'Ancrage.
- **Transfert de poids** : la force d'un coup dépend du poids engagé (appui avant, rotation des hanches), pas seulement de l'animation.
- **Friction** : le sol mouillé, sableux ou boueux réduit l'adhérence et allonge les reculs.
- **Collision** : les corps se repoussent ; un corps projeté contre un mur transmet un impact au mur (environnement) et à lui-même.
- **Recul** : la vitesse de recul est calculée par le système de dégâts (énergie transmise / masse) et appliquée au corps, pas jouée par une animation fixe.

### Anti-glisse

- Les pieds sont verrouillés au sol pendant les appuis (cinématique inverse, phase d'appui détectée).
- L'animation est choisie par correspondance de mouvement (motion matching) dans une base de captures, puis corrigée physiquement (animation physique partielle) pour absorber les impacts.
- Chaque déplacement a une phase d'accélération et de décélération visibles.

## 5. Défense

Se défendre a toujours un coût : la garde protège le corps mais use l'équipement et le Souffle, et les bras qui bloquent encaissent le choc.

| Action | Commande | Fenêtre | Effet | Coût persistant |
| --- | --- | --- | --- | --- |
| Garde | Garde maintenue + direction (haute, basse, latérale) | continue | le coup frappe l'arme, le bouclier ou les avant-bras | usure de l'arme ou du bouclier ; contusions aux avant-bras sur coups lourds |
| Parade | Garde au moment de l'impact | 6 frames (0,1 s) | dévie le coup, l'adversaire est déséquilibré | choc arme contre arme résolu par le système de dégâts |
| Contre | attaque juste après une parade ou une esquive parfaite | 10 frames | punition garantie | — |
| Esquive | Esquive + direction | invulnérabilité partielle, selon le combattant | sort de la trajectoire | Souffle |
| Esquive parfaite | Esquive au dernier moment | 4 frames | ouvre un contre | Souffle |
| Rupture de prise | Léger + Lourd pendant une saisie | 8 frames | se dégage | Souffle |

### Règles

- **Garde selon la hauteur** : une garde haute laisse les jambes exposées ; une garde basse, la tête.
- **Garde selon l'équipement** : un bouclier protège mieux mais finit par se fendre ; une garde à mains nues transmet le choc aux avant-bras.
- **Garde brisée** : quand le Souffle est vide, la garde cède et l'Ancrage chute ; ce n'est pas un compteur abstrait.
- **Parade et état** : une arme très endommagée peut se briser en parant (§ arme contre arme du GDD des dégâts).

## 6. Dégâts persistants, blessures et fatigue en combat

Le Damage Priority & Resolution System est au centre du jeu : le joueur choisit où frapper, et chaque zone touchée change le reste du combat.

### Visée de zone

- La direction tenue au moment d'un coup choisit la **hauteur** (haute, moyenne, basse) et le **côté** (gauche, droite). Le coup suit une trajectoire réelle ; ce qu'il touche est décidé par les collisions, pas par une case.
- Les techniques spécifiques visent des zones précises : fixations, articulations, mains.
- Frapper plusieurs fois le même endroit est une stratégie : une pièce fissurée cède plus vite.

### Ce que le joueur voit et ce que cela change

| État | Visible à l'écran | Effet en jeu |
| --- | --- | --- |
| Armure fissurée | fissure, son fêlté | protège moins à cet endroit |
| Armure déformée ou brisée | bosse, pièce qui pend ou tombe | zone exposée |
| Arme endommagée | ébréchures, fissures, lame tordue | force et tranchant réduits, risque de rupture |
| Arme cassée | lame absente, manche seul | moveset de l'arme cassée ou mains nues |
| Vêtement sale, déchiré | poussière, boue, accrocs | peu d'effet en jeu ; lecture de l'historique |
| Blessure au bras | bras plus bas, garde plus lente | vitesse d'attaque et garde réduites |
| Blessure à la main | main crispée | prise affaiblie, précision réduite, risque de désarmement |
| Blessure à la jambe | boiterie | déplacement et esquive réduits |
| Blessure à la tête | vacillement | moins résistant au déséquilibre |
| Saignement | sang qui coule, gouttes au sol | augmente la fatigue au fil du temps |
| Fatigue | respiration forte, sueur, posture basse | Souffle plafonné, récupération lente |

Toutes ces conséquences sont **progressives** et plafonnées : aucun membre ne descend sous 35 % de sa fonction, et une petite blessure n'a qu'un petit effet.

### Fatigue

- **Monte** avec l'effort (attaques, esquives, prises), les chocs encaissés et la perte de sang.
- **Se voit** : respiration plus forte, transpiration, posture plus basse, mouvements légèrement plus lents, expressions de douleur.
- **Agit** : le plafond du Souffle baisse, sa récupération ralentit. L'IA d'un combattant fatigué devient plus prudente.
- **Ne frustre pas** : la fatigue ne retire jamais le contrôle ; elle réduit les marges.
- **Ne se réinitialise pas** : seul le repos entre deux combats la réduit.

## 7. Armes, perte d'arme et armes improvisées

Une arme cassée reste cassée : le combattant continue avec ce qu'il lui reste, et jamais avec une arme visuellement intacte.

### États d'une arme

intacte → endommagée → fissurée → déformée → cassée. Une arme peut aussi perdre une partie (lame, tête, garde), tomber ou être abandonnée.

| Situation | Ce que fait le jeu |
| --- | --- |
| Arme endommagée | force réduite, tranchant émoussé ; animations identiques |
| Lame ou tête perdue | la partie tombe dans l'arène et y reste ; le combattant passe à un moveset « arme brisée » (manche, tronçon) |
| Arme cassée en deux | même chose ; le morceau peut être ramassé comme arme improvisée |
| Désarmement | l'arme tombe à un endroit calculé par la physique ; elle peut être récupérée (action de ramassage, vulnérable) |
| Arme abandonnée | le combattant la lâche volontairement pour passer à mains nues ; plus rapide, moins de portée |

Chaque combattant a donc trois movesets : avec arme, arme brisée, mains nues. Les combattants à mains nues (Sowadé, Bassù, Zékiya) n'ont pas d'état « arme » mais leurs gantelets et gants suivent les mêmes règles d'usure.

### Armes improvisées

| Objet | Arènes | Type | Intégrité |
| --- | --- | --- | --- |
| Barre de métal | Aboké | contondant | moyenne |
| Tabouret, étal | Marché de Minuit | contondant | faible |
| Pagaie, rame | Delta | contondant | faible |
| Tison, outil de forge | Forge Ouverte | contondant, feu | moyenne |
| Fragment de statue | Cour des Assis | lourd | élevée, très lent |
| Éclat de verre de foudre | Cirque des Dents | tranchant | très faible, blesse aussi la main |
| Morceau d'arme brisée | partout | selon le morceau | celle du morceau |

Les armes improvisées suivent le système de dégâts comme les autres : matériau, intégrité, rupture.

## 8. Environnement interactif et arènes à mémoire

L'arène raconte le combat : un mur détruit reste détruit, une vitre brisée reste brisée, un sol fissuré reste fissuré, une végétation arrachée reste arrachée.

### Éléments d'arène

| Élément | Interaction | État persistant |
| --- | --- | --- |
| Murs | projection contre, rebond, attaque contextuelle | fissuré → percé → effondré (ouvre une nouvelle zone) |
| Colonnes, statues | projection, appui, arme improvisée (fragment) | fissurée → brisée ; fragments au sol |
| Vitres, verre | projection à travers | brisée ; éclats au sol qui blessent en roulant dessus |
| Sol | impacts lourds, Résonance Terre, chutes | fissures, cratères, verre fondu |
| Végétation | coupures, feu, chutes | arrachée, brûlée, couchée |
| Eau | combats dans l'eau, chutes | trouble, sang dilué qui dérive |
| Objets mobiles | étals, chariots, pirogues | renversés, brisés, déplacés |
| Bords et niveaux | projection vers un niveau inférieur | transition d'arène, dégâts de chute |

### Attaques contextuelles

Lourd + Technique près d'un élément d'arène : projeter l'adversaire contre une colonne, l'écraser contre un étal, briser une vitre avec son corps. Elles sont fortes et modifient l'arène de façon définitive : chaque arène n'en offre qu'un nombre limité, puisque l'élément utilisé est détruit.

### Transitions

Les arènes ont deux ou trois niveaux. Une projection assez puissante contre un bord ou un mur fragile fait passer le combat à un autre niveau (le Marché de Minuit descend vers le quai, la Marche des Mille Marches descend d'un palier).

### Météo et lumière

La pluie mouille le sol (friction), éteint les feux et dilue le sang ; elle aggrave la Foudre. Le coucher du soleil allonge les ombres, ce qui étend le terrain d'Amisé et de Sénou. Les éclairs illuminent brièvement l'arène. Ces changements sont jouables, pas seulement visuels.

### Limite technique

Le nombre de débris persistants est plafonné par arène ; au-delà, les plus petits fusionnent en décals. Les éléments qui comptent pour le jeu (murs, colonnes, armes au sol) ne disparaissent jamais.

## 9. Pouvoirs, capacités ultimes et finishers

Les pouvoirs sont spectaculaires mais physiques : une Résonance amplifie une énergie existante, traverse la chaîne de dégâts et laisse une Marque permanente sur son porteur.

### Pouvoirs

- **Coût** : chaque usage consomme du Kalé ; les usages forts laissent une Marque (tracé lumineux permanent sous la peau).
- **Cohérence** : le feu brûle ce qui est inflammable, la foudre traverse le métal et l'eau, le vent déplace ce qui est léger. Un pouvoir ne fait rien qui contredise le matériau qu'il touche.
- **Contre-jeu** : chaque Résonance a un contre naturel (Eau contre Feu, Lumière contre Ombre, ancrage contre Vent).

### Capacités ultimes

- Une par combattant, accessible quand les trois segments de Kalé sont pleins.
- Elle commence par un coup d'ouverture qui doit toucher ; si l'adversaire bloque ou esquive, le Kalé est perdu.
- Séquence cinématique de 3 à 6 secondes : ralentissement, changement d'angle, travelling, profondeur de champ, cadrage rapproché.
- Ses dégâts passent par la chaîne normale et sont plafonnés comme les autres. Ce qu'elle détruit reste détruit après la cinématique.

### Finishers

- Déclenchables quand l'adversaire tombe à zéro de santé dans les modes qui l'autorisent.
- Ils montrent le combattant **tel qu'il est** : un Tandé sans épaulière et une Mâchoire ébréchée jouent leur finisher dans cet état.
- Ils sont réalistes, sans démembrement ni gore gratuit : la brutalité vient du poids et du son, pas de l'excès. Une option permet de les désactiver.
- Aucun finisher ne reprend la forme ou le nom d'une mécanique de franchise existante.

## 10. Caméra

La caméra sert d'abord le jeu : elle accentue les impacts sans jamais cacher une information nécessaire.

| Contexte | Comportement | Contraintes |
| --- | --- | --- |
| Exploration | troisième personne cinématographique, focale longue, léger retard sur le mouvement | contrôle libre par le joueur |
| Combat | caméra latérale dynamique sur un plan 3D, qui suit l'axe entre les deux combattants | les deux corps toujours entiers à l'écran ; jamais de coupure pendant une action jouable |
| Impact lourd | micro-tremblement, léger zoom, arrêt sur image de quelques frames (hitstop) | hitstop identique pour les deux joueurs |
| Ultime | séquence cinématique : ralentissement, angle, travelling, profondeur de champ, gros plan | 3 à 6 secondes, aucune entrée attendue pendant la séquence |
| Début de combat | silence → environnement → regard → dialogue → tension → posture → combat | passable après la première fois |
| Fin de combat | silence → respiration → arène détruite → état du personnage → conséquence | la caméra montre l'état réel des combattants |

Les cinématiques utilisent les modèles et l'état de jeu ; aucune scène pré-calculée ne montre un personnage plus intact qu'il ne l'est.

## 11. Modes de jeu et persistance

> Section déplacée sans modification vers [modes-jeu.md](modes-jeu.md).

<!-- SECTION DÉPLACÉE : modes-jeu.md -->
## 12. Technique de jeu de combat

Un jeu de combat classé en ligne exige une simulation déterministe à 60 images par seconde et un netcode à rollback ; le système de dégâts persistants doit être conçu pour cela dès le départ.

### Frames

- La logique tourne à 60 frames par seconde fixes, indépendamment du rendu.
- Chaque attaque a ses données de frames : démarrage, frames actives, récupération, avantage au bloc et à la touche.
- L'état de l'équipement et les blessures modifient certaines données de frames de façon discrète et documentée (ex. +2 frames de récupération avec un bras sous 60 % de fonction), jamais de façon continue et illisible.

### Netcode

- **Rollback** : chaque client simule localement, puis corrige quand les entrées distantes arrivent en rembobinant quelques frames.
- **Conséquence pour les dégâts** : le Damage State doit pouvoir être sauvegardé et restauré à chaque frame. Il doit donc être compact (quelques kilo-octets), sans allocation dynamique, et déterministe (calcul en virgule fixe ou flottants strictement contrôlés).
- **Séparation** : la simulation (état, frames, dégâts) est rembobinable ; la présentation (sang, débris, masques, particules) ne l'est pas. Elle se recale sur l'état après une correction.
- Ce choix modifie l'architecture du GDD des dégâts, qui prévoyait un serveur autoritaire sans rollback.

### Mode Training

- Affichage des frames, des données de chaque attaque, de la portée, des volumes de collision et des combos.
- Affichage de la chaîne de dégâts de chaque impact : couches touchées, énergie absorbée, transmise, blessure créée.
- Réglage de l'état de départ : équipement neuf ou endommagé, blessures, fatigue.
- Enregistrement et lecture de séquences de l'adversaire.

## 13. Équilibrage compétitif et questions ouvertes

La persistance rend l'équilibrage plus difficile qu'un jeu de combat classique ; il repose sur des plafonds clairs, une information lisible et des mesures automatisées.

### Principes

- **Plafonds** : dégâts par coup et par fenêtre de temps, fonction minimale des membres, perte d'équilibre maximale par coup.
- **Lisibilité** : toute faiblesse exploitable a un signe visuel et sonore.
- **Contre-jeu** : chaque archétype a des réponses ; chaque arme fragile compense par une force.
- **Mesure** : la simulation étant déterministe, des milliers de combats automatisés mesurent le taux de victoire par matchup, l'avantage du premier coup et l'effet de la persistance sur un set.
- **Ajustement par données** : toutes les valeurs (matériaux, zones, frames, coûts) sont des données, réglables sans code.

### Questions ouvertes

- [ ] Persistance en Ranked : par set (proposition de ce document) ou nouvel état à chaque manche ?
- [ ] Défaite par hémorragie : possible ou non ?
- [ ] Finishers : inclus dans tous les modes ou seulement en Histoire et Versus ?
- [ ] Nombre de manches par set en Ranked.
- [ ] Les boss sont-ils jouables en Versus ?
- [ ] Faut-il un mode « Classique » sans persistance pour les tournois e-sport, ou la persistance est-elle l'identité du jeu jusqu'au bout ?
