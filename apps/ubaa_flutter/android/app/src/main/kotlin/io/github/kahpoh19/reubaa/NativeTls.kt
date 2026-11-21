package io.github.kahpoh19.reubaa

import android.content.Context

/**
 * 系统证书验证要在任何 Core HTTP 请求前初始化。
 *
 * 界面和后台服务都可能先拉起引擎，所以单独放一个对象，两边都调用；重复初始化没关系。
 */
object NativeTls {
    private external fun initializeTls(context: Context): Boolean

    fun initialize(context: Context) {
        System.loadLibrary("ubaa_flutter_bridge")
        check(initializeTls(context.applicationContext)) { "系统证书验证初始化失败" }
    }
}
