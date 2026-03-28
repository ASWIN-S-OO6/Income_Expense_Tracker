package com.nth.expense_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import android.widget.RemoteViews

class QuickAddWidgetProvider : HomeWidgetProvider() {

    companion object {
        // Key written by Flutter when the active book changes.
        // Flutter side: HomeWidget.saveWidgetData('widget_book_id', book.id)
        //               HomeWidget.saveWidgetData('widget_book_name', book.name)
        private const val KEY_BOOK_ID   = "widget_book_id"
        private const val KEY_BOOK_NAME = "widget_book_name"
        private const val FALLBACK_NAME = "Expense Tracker"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        // Read the last-opened book stored by Flutter via HomeWidget.saveWidgetData
        val bookId   = widgetData.getString(KEY_BOOK_ID,   null)
        val bookName = widgetData.getString(KEY_BOOK_NAME, null) ?: FALLBACK_NAME

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.quick_add_widget).apply {

                // Show the active book name in the header
                setTextViewText(R.id.tv_book_name, bookName)

                // Build URIs that include the bookId so Flutter can pre-select it
                val incomeUri  = buildUri("income",  bookId)
                val expenseUri = buildUri("expense", bookId)

                val incomeIntent  = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, incomeUri
                )
                val expenseIntent = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, expenseUri
                )

                setOnClickPendingIntent(R.id.btn_add_income,  incomeIntent)
                setOnClickPendingIntent(R.id.btn_add_expense, expenseIntent)
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun buildUri(type: String, bookId: String?): Uri {
        return if (bookId != null) {
            Uri.parse("expense_tracker://add?type=$type&bookId=$bookId")
        } else {
            Uri.parse("expense_tracker://add?type=$type")
        }
    }
}
