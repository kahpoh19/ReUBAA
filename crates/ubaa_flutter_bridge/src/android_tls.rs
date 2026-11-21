//! Android系统证书验证宿主，先于任何Core HTTP请求初始化。

use jni::EnvUnowned;
use jni::objects::JObject;
use jni::sys::{JNI_TRUE, jboolean};

// JVM精确查找此符号；ubaa_flutter包中的下划线按JNI规则编码为_1。
// 界面和后台服务都会拉起引擎，初始化放在宿主的 NativeTls 单例里。
#[unsafe(no_mangle)]
pub extern "system" fn Java_io_github_kahpoh19_reubaa_NativeTls_initializeTls<'caller>(
    mut env: EnvUnowned<'caller>,
    _this: JObject<'caller>,
    context: JObject<'caller>,
) -> jboolean {
    env.with_env(|env| {
        rustls_platform_verifier::android::init_with_env(env, context)?;
        Ok::<_, jni::errors::Error>(JNI_TRUE)
    })
    .resolve::<jni::errors::ThrowRuntimeExAndDefault>()
}
