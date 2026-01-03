# Analyse d'optimisation - Module druid-ingestion

## 📊 Vue d'ensemble

- **Total fichiers Java**: 23
- **Total lignes de code**: ~1034 lignes
- **Fichiers les plus volumineux**:
  - `SpecBuilder.java`: 208 lignes
  - `ConfigLoader.java`: 106 lignes
  - `Config.java`: 97 lignes
  - `DruidIngestion.java`: 93 lignes

## 🎯 Opportunités d'optimisation identifiées

### 1. **Code mort / Inutilisé** ⚠️ PRIORITÉ HAUTE

#### S3Uploader.java (36 lignes) - À SUPPRIMER
- **Problème**: Classe placeholder qui lance toujours `UnsupportedOperationException`
- **Impact**: 36 lignes de code mort
- **Action**: Supprimer la classe et son import dans `UploadDescriptorCommand`
- **Gain**: -36 lignes

#### UploadDescriptorCommand - Simplification
- **Problème**: Commande qui ne fait rien de concret (juste des logs)
- **Impact**: 53 lignes pour une commande inutile
- **Action**: Simplifier drastiquement ou supprimer si vraiment inutile
- **Gain potentiel**: -30 à -53 lignes

### 2. **Duplications de code** ⚠️ PRIORITÉ HAUTE

#### Pattern répétitif dans toutes les commandes
```java
// Répété dans BuildCommand, DeployCommand, StatusCommand, UploadDescriptorCommand
return DruidIngestion.handleCommand(() -> {
    var root = DruidIngestion.getModuleRoot();
    Validator.validateEnvironment(env);
    var config = Config.load(root, env);
    // ... logique spécifique
});
```

**Solution**: Créer une méthode helper dans `DruidIngestion`:
```java
public static <T> T withConfig(String env, Function<Config, T> action) throws Exception {
    var root = getModuleRoot();
    Validator.validateEnvironment(env);
    var config = Config.load(root, env);
    return action.apply(config);
}
```

**Gain**: -12 lignes × 4 commandes = -48 lignes

#### Accès répétitif à HttpClient.mapper()
- **Problème**: `DruidIngestion.getHttpClient().mapper()` appelé 5+ fois
- **Solution**: Exposer `ObjectMapper` directement ou créer une constante statique
- **Gain**: -10 lignes, code plus lisible

### 3. **Simplifications possibles** ⚠️ PRIORITÉ MOYENNE

#### DeployCommand - Appel à BuildCommand
- **Problème**: Crée une instance de `BuildCommand` et modifie ses champs directement
- **Solution**: Extraire la logique de build dans une méthode statique partagée
- **Gain**: -5 lignes, meilleure séparation des responsabilités

#### StatusCommand - Utilisation répétitive du mapper
```java
var json = DruidIngestion.getHttpClient().execute(request, 2);
var jsonObj = DruidIngestion.getHttpClient().mapper().readValue(json, Object.class);
System.out.println(DruidIngestion.getHttpClient().mapper().writerWithDefaultPrettyPrinter().writeValueAsString(jsonObj));
```

**Solution**: Créer une méthode helper dans `HttpClient`:
```java
public String executeAndPrettyPrint(Request request, int maxRetries) throws DruidException {
    var json = execute(request, maxRetries);
    try {
        var obj = mapper.readValue(json, Object.class);
        return mapper.writerWithDefaultPrettyPrinter().writeValueAsString(obj);
    } catch (Exception e) {
        return json; // Fallback
    }
}
```

**Gain**: -2 lignes, code plus lisible

#### HttpClient - ObjectMapper comme constante
- **Problème**: `ObjectMapper` créé à chaque instance
- **Solution**: Utiliser une constante statique (thread-safe)
- **Gain**: -1 ligne, meilleure performance

### 4. **Améliorations structurelles** ⚠️ PRIORITÉ BASSE

#### ConfigExtractor - Méthode unquote() inutilisée ?
- **Vérifier**: Si `unquote()` est vraiment nécessaire
- **Action**: Analyser les cas d'usage

#### Exception handling - Simplification
- **Problème**: `DruidIngestion.handleCommand()` a 4 blocs catch similaires
- **Solution**: Utiliser un pattern plus fonctionnel
- **Gain**: -5 lignes

#### BuildCommand - SpecBuilder comme constante
- **Problème**: `SpecBuilder` créé comme constante statique mais pourrait être singleton
- **Solution**: Vérifier si nécessaire (actuellement OK)

## 📈 Gains estimés

| Catégorie | Gain estimé | Priorité |
|-----------|-------------|----------|
| Code mort (S3Uploader) | -36 lignes | HAUTE |
| UploadDescriptorCommand | -30 lignes | HAUTE |
| Duplication commandes | -48 lignes | HAUTE |
| HttpClient.mapper() | -10 lignes | MOYENNE |
| DeployCommand | -5 lignes | MOYENNE |
| StatusCommand | -2 lignes | MOYENNE |
| Exception handling | -5 lignes | BASSE |
| **TOTAL ESTIMÉ** | **-136 lignes** | |

**Réduction estimée**: ~13% du code total

## 🎯 Plan d'action recommandé

### Phase 1: Nettoyage (Gain: -66 lignes)
1. ✅ Supprimer `S3Uploader.java`
2. ✅ Simplifier `UploadDescriptorCommand`
3. ✅ Nettoyer les imports inutilisés

### Phase 2: Refactoring (Gain: -58 lignes)
1. ✅ Créer méthode helper `withConfig()` dans `DruidIngestion`
2. ✅ Simplifier l'accès à `ObjectMapper`
3. ✅ Extraire logique de build partagée

### Phase 3: Optimisations (Gain: -12 lignes)
1. ✅ Améliorer `StatusCommand`
2. ✅ Simplifier exception handling
3. ✅ Optimiser `HttpClient`

## ✅ Critères de qualité

- ✅ Pas de régression fonctionnelle
- ✅ Tests unitaires passent
- ✅ Code plus lisible et maintenable
- ✅ Réduction de la duplication
- ✅ Meilleure séparation des responsabilités

