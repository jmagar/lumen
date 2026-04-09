# SWE-Bench Detail Report

Generated: 2026-04-09 06:22 UTC

---

## kotlin-hard [kotlin]

**Issue:** MissingFieldException when trying to deserialize enum field in sealed hierarchy

> Exception occurs when trying to deserialize an object as a sealed root, if it contains a field with an unknown enum value.
> 
> ```
> Exception in thread "main" kotlinx.serialization.MissingFieldException: Field 'status' is required for type with serial name 'org.example.Feature', but it was missing at path: $
> ```
> 
> Reproduction:
> 
> ```kotlin
> @Serializable
> internal sealed class TestSealed {
>     @Serializable
>     @SerialName("foo")
>     data class FirstSealed(@SerialName("feature") val feature: Feature) : TestSealed()
> }
> 
> @Serializable
> internal data class Feature(
>     @SerialName("status") val status: FeatureStatus?,
> )
> 
> @Serializable
> internal enum class FeatureStatus {
>     @SerialName("first") First,
>     @SerialName("second") Second,
> }
> 
> val json = """{\n    "feature": {\n      "status": "unknown"\n    },\n    "type": "foo"\n}"""
> 
> fun main() {
>     val parser = Json {\n        coerceInputValues = true\n        explicitNulls = false\n        ignoreUnknownKeys = true\n    }
>     println(parser.decodeFromString<TestSealed>(json))
> }
> ```
> 
> If decoding as the concrete implementation directly, it works: `parser.decodeFromString<TestSealed.FirstSealed>(json)`
> 
> Also noticed that moving the "type" key before "feature" in the JSON fixes the problem. Does the order of keys matter?
> 
> Expected behavior: Decode succeeds and prints `FirstSealed(feature=Feature(status=null))`
> 
> Environment: Kotlin 2.1.0, Library version 1.8.0, JVM platform

### Metrics

| Scenario | Duration | Input Tok | Cache Read | Output Tok | Cost |
|----------|----------|-----------|------------|------------|------|
| **baseline** | 592.1s | 595 | 4873279 | 24501 | $0.7657 |
| **with-lumen** | 348.2s | 462 | 4261984 | 20268 | $0.6659 |

### baseline

```diff
diff --git a/formats/json-tests/commonTest/src/kotlinx/serialization/features/SealedPolymorphismTest.kt b/formats/json-tests/commonTest/src/kotlinx/serialization/features/SealedPolymorphismTest.kt
index 4cc289a..14ede82 100644
--- a/formats/json-tests/commonTest/src/kotlinx/serialization/features/SealedPolymorphismTest.kt
+++ b/formats/json-tests/commonTest/src/kotlinx/serialization/features/SealedPolymorphismTest.kt
@@ -9,6 +9,8 @@ import kotlinx.serialization.json.Json
 import kotlinx.serialization.modules.*
 import kotlinx.serialization.test.assertStringFormAndRestored
 import kotlin.test.Test
+import kotlin.test.assertEquals
+import kotlin.test.assertTrue
 
 class SealedPolymorphismTest {
 
@@ -60,4 +62,55 @@ class SealedPolymorphismTest {
             json
         )
     }
+
+    @Test
+    fun testSealedClassWithUnknownEnumValueInField() {
+        val jsonWithUnknownEnum = """{
+            "feature": {
+              "status": "unknown"
+            },
+            "type": "foo"
+        }"""
+
+        val parser = Json {
+            coerceInputValues = true
+            explicitNulls = false
+            ignoreUnknownKeys = true
+        }
+
+        // Should succeed and deserialize with status = null due to coercion
+        val result = parser.decodeFromString<TestSealedWithEnum>(jsonWithUnknownEnum)
+        assertTrue(result is TestSealedWithEnum.FirstSealed)
+        assertEquals(null, result.feature.status)
+
+        // Also test when type field comes first
+        val jsonWithTypeFirst = """{
+            "type": "foo",
+            "feature": {
+              "status": "unknown"
+            }
+        }"""
+
+        val result2 = parser.decodeFromString<TestSealedWithEnum>(jsonWithTypeFirst)
+        assertTrue(result2 is TestSealedWithEnum.FirstSealed)
+        assertEquals(null, result2.feature.status)
+    }
+}
+
+@Serializable
+sealed class TestSealedWithEnum {
+    @Serializable
+    @SerialName("foo")
+    data class FirstSealed(@SerialName("feature") val feature: FeatureWithStatus) : TestSealedWithEnum()
+}
+
+@Serializable
+data class FeatureWithStatus(
+    @SerialName("status") val status: StatusEnum?,
+)
+
+@Serializable
+enum class StatusEnum {
+    @SerialName("first") First,
+    @SerialName("second") Second,
 }
diff --git a/formats/json/commonMain/src/kotlinx/serialization/json/internal/TreeJsonDecoder.kt b/formats/json/commonMain/src/kotlinx/serialization/json/internal/TreeJsonDecoder.kt
index 2121b27..34a3e24 100644
--- a/formats/json/commonMain/src/kotlinx/serialization/json/internal/TreeJsonDecoder.kt
+++ b/formats/json/commonMain/src/kotlinx/serialization/json/internal/TreeJsonDecoder.kt
@@ -212,9 +212,20 @@ private open class JsonTreeDecoder(
             val name = descriptor.getTag(position++)
             val index = position - 1
             forceNull = false
-            if ((name in value || absenceIsNull(descriptor, index))
-                && (!configuration.coerceInputValues || !coerceInputValue(descriptor, index, name))
-            ) {
+            if (name in value || absenceIsNull(descriptor, index)) {
+                if (configuration.coerceInputValues && coerceInputValue(descriptor, index, name)) {
+                    // Coercion succeeded. For enums with unknown values:
+                    // - If the field is nullable and not explicitly optional, coerce to null
+                    // - Otherwise, skip the field and use default/absent handling
+                    val elementDescriptor = descriptor.getElementDescriptor(index)
+                    if (elementDescriptor.kind == SerialKind.ENUM && elementDescriptor.isNullable && !descriptor.isElementOptional(index)) {
+                        // Mark as null but still return the index so the deserializer handles it
+                        forceNull = true
+                        return index
+                    }
+                    // Skip the field (use default or absence handling)
+                    continue
+                }
                 return index
             }
         }
```

### with-lumen

```diff
diff --git a/formats/json-tests/commonTest/src/kotlinx/serialization/features/SealedPolymorphismTest.kt b/formats/json-tests/commonTest/src/kotlinx/serialization/features/SealedPolymorphismTest.kt
index 4cc289a..c91f3f5 100644
--- a/formats/json-tests/commonTest/src/kotlinx/serialization/features/SealedPolymorphismTest.kt
+++ b/formats/json-tests/commonTest/src/kotlinx/serialization/features/SealedPolymorphismTest.kt
@@ -9,6 +9,7 @@ import kotlinx.serialization.json.Json
 import kotlinx.serialization.modules.*
 import kotlinx.serialization.test.assertStringFormAndRestored
 import kotlin.test.Test
+import kotlin.test.assertEquals
 
 class SealedPolymorphismTest {
 
@@ -29,6 +30,24 @@ class SealedPolymorphismTest {
         data class Baz(val baz: String) : Foo()
     }
 
+    @Serializable
+    sealed class TestSealed {
+        @Serializable
+        @SerialName("foo")
+        data class FirstSealed(@SerialName("feature") val feature: Feature) : TestSealed()
+    }
+
+    @Serializable
+    data class Feature(
+        @SerialName("status") val status: FeatureStatus?,
+    )
+
+    @Serializable
+    enum class FeatureStatus {
+        @SerialName("first") First,
+        @SerialName("second") Second,
+    }
+
     val sealedModule = SerializersModule {
         polymorphic(Foo::class) {
             subclass(Foo.Bar.serializer())
@@ -60,4 +79,16 @@ class SealedPolymorphismTest {
             json
         )
     }
+
+    @Test
+    fun testSealedClassWithUnknownEnumInNullableField() {
+        val parser = Json {
+            coerceInputValues = true
+            explicitNulls = false
+            ignoreUnknownKeys = true
+        }
+        val jsonString = """{"feature":{"status":"unknown"},"type":"foo"}"""
+        val result = parser.decodeFromString<TestSealed>(jsonString)
+        assertEquals(TestSealed.FirstSealed(Feature(null)), result)
+    }
 }
diff --git a/formats/json/commonMain/src/kotlinx/serialization/json/internal/TreeJsonDecoder.kt b/formats/json/commonMain/src/kotlinx/serialization/json/internal/TreeJsonDecoder.kt
index 2121b27..cead34d 100644
--- a/formats/json/commonMain/src/kotlinx/serialization/json/internal/TreeJsonDecoder.kt
+++ b/formats/json/commonMain/src/kotlinx/serialization/json/internal/TreeJsonDecoder.kt
@@ -212,10 +212,19 @@ private open class JsonTreeDecoder(
             val name = descriptor.getTag(position++)
             val index = position - 1
             forceNull = false
-            if ((name in value || absenceIsNull(descriptor, index))
-                && (!configuration.coerceInputValues || !coerceInputValue(descriptor, index, name))
-            ) {
-                return index
+            if (name in value || absenceIsNull(descriptor, index)) {
+                if (!configuration.coerceInputValues || !coerceInputValue(descriptor, index, name)) {
+                    return index
+                } else {
+                    // Field can be coerced - for non-optional fields, return the index and set forceNull
+                    // so it's treated as null and marked as "seen" in the generated code
+                    val isOptional = descriptor.isElementOptional(index)
+                    if (!isOptional) {
+                        forceNull = true
+                        return index
+                    }
+                    // For optional fields, continue to skip
+                }
             }
         }
         return CompositeDecoder.DECODE_DONE
```


