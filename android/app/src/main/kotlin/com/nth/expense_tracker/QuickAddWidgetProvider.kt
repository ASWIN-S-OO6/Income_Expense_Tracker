package com.nth.expense_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import android.widget.RemoteViews

class QuickAddWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.quick_add_widget).apply {
                // Income Button - Launch App with specific intent
                val incomeIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("expense_tracker://add?type=income")
                )
                setOnClickPendingIntent(R.id.btn_add_income, incomeIntent)

                // Expense Button - Launch App with specific intent
                val expenseIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("expense_tracker://add?type=expense")
                )
                setOnClickPendingIntent(R.id.btn_add_expense, expenseIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
