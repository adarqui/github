{-# LANGUAGE OverloadedStrings, DeriveGeneric, DeriveDataTypeable #-}
{-# LANGUAGE CPP #-}
-- | The webhooks API, as described at
-- <https://developer.github.com/v3/repos/hooks/>
-- <https://developer.github.com/webhooks>

module Github.Repos.Webhooks (

-- * Querying repositories
  webhooksFor'
 ,webhookFor'

-- ** Create
 ,createRepoWebhook'

-- ** Edit  
 ,editRepoWebhook'

-- ** Test  
 ,testPushRepoWebhook'
 ,pingRepoWebhook'

-- ** Delete  
 ,deleteRepoWebhook'
 ,NewRepoWebhook(..)
 ,EditRepoWebhook(..)
 ,RepoOwner
 ,RepoName
 ,RepoWebhookId
) where

import Github.Data
import Github.Private
import Control.DeepSeq (NFData)
import Data.Data
import qualified Data.Map as M
import Network.HTTP.Conduit
import Network.HTTP.Types
import Data.Aeson
import GHC.Generics (Generic)

type RepoOwner = String
type RepoName = String
type RepoWebhookId = Int
    
data NewRepoWebhook = NewRepoWebhook {
  newRepoWebhookName :: String
 ,newRepoWebhookConfig :: M.Map String String
 ,newRepoWebhookEvents :: Maybe [RepoWebhookEvent]
 ,newRepoWebhookActive :: Maybe Bool
} deriving (Eq, Ord, Show, Typeable, Data, Generic)

instance NFData NewRepoWebhook

data EditRepoWebhook = EditRepoWebhook {
  editRepoWebhookConfig :: Maybe (M.Map String String)
 ,editRepoWebhookEvents :: Maybe [RepoWebhookEvent]
 ,editRepoWebhookAddEvents :: Maybe [RepoWebhookEvent]
 ,editRepoWebhookRemoveEvents :: Maybe [RepoWebhookEvent]
 ,editRepoWebhookActive :: Maybe Bool
} deriving (Eq, Ord, Show, Typeable, Data, Generic)
                
instance NFData EditRepoWebhook

instance ToJSON NewRepoWebhook where
  toJSON (NewRepoWebhook { newRepoWebhookName = name
                         , newRepoWebhookConfig = config
                         , newRepoWebhookEvents = events
                         , newRepoWebhookActive = active

             }) = object
             [ "name" .= name
             , "config" .= config
             , "events" .= events
             , "active" .= active
             ]

instance ToJSON EditRepoWebhook where             
  toJSON (EditRepoWebhook { editRepoWebhookConfig = config
                          , editRepoWebhookEvents = events
                          , editRepoWebhookAddEvents = addEvents
                          , editRepoWebhookRemoveEvents = removeEvents
                          , editRepoWebhookActive = active
             }) = object
             [ "config" .= config
             , "events" .= events
             , "add_events" .= addEvents
             , "remove_events" .= removeEvents
             , "active" .= active
             ]
             
webhooksFor' :: GithubAuth -> RepoOwner -> RepoName -> IO (Either Error [RepoWebhook])
webhooksFor' auth owner reqRepoName =
  githubGet' (Just auth) ["repos", owner, reqRepoName, "hooks"]

webhookFor' :: GithubAuth -> RepoOwner -> RepoName -> RepoWebhookId -> IO (Either Error RepoWebhook)
webhookFor' auth owner reqRepoName webhookId =
  githubGet' (Just auth) ["repos", owner, reqRepoName, "hooks", (show webhookId)]

createRepoWebhook' :: GithubAuth -> RepoOwner -> RepoName -> NewRepoWebhook -> IO (Either Error RepoWebhook)
createRepoWebhook' auth owner reqRepoName = githubPost auth ["repos", owner, reqRepoName, "hooks"]

editRepoWebhook' :: GithubAuth -> RepoOwner -> RepoName -> RepoWebhookId -> EditRepoWebhook -> IO (Either Error RepoWebhook)
editRepoWebhook' auth owner reqRepoName webhookId edit = githubPatch auth ["repos", owner, reqRepoName, "hooks", (show webhookId)] edit
                                                            
testPushRepoWebhook' :: GithubAuth -> RepoOwner -> RepoName -> RepoWebhookId -> IO (Either Error Status)
testPushRepoWebhook' auth owner reqRepoName webhookId =
  doHttpsStatus "POST" (createWebhookOpPath owner reqRepoName webhookId (Just "tests")) auth (Just . RequestBodyLBS . encode $ (decode "{}" :: Maybe (M.Map String Int)))

pingRepoWebhook' :: GithubAuth -> RepoOwner -> RepoName -> RepoWebhookId -> IO (Either Error Status)
pingRepoWebhook' auth owner reqRepoName webhookId =
  doHttpsStatus "POST" (createWebhookOpPath owner reqRepoName webhookId (Just "pings")) auth Nothing

deleteRepoWebhook' :: GithubAuth -> RepoOwner -> RepoName -> RepoWebhookId -> IO (Either Error Status)
deleteRepoWebhook' auth owner reqRepoName webhookId =
  doHttpsStatus "DELETE" (createWebhookOpPath owner reqRepoName webhookId Nothing) auth Nothing

createBaseWebhookPath :: RepoOwner -> RepoName -> RepoWebhookId -> String
createBaseWebhookPath owner reqRepoName webhookId = buildPath ["repos", owner, reqRepoName, "hooks", show webhookId]

createWebhookOpPath :: RepoOwner -> RepoName -> RepoWebhookId -> Maybe String -> String
createWebhookOpPath owner reqRepoName webhookId Nothing = createBaseWebhookPath owner reqRepoName webhookId
createWebhookOpPath owner reqRepoName webhookId (Just operation) = createBaseWebhookPath owner reqRepoName webhookId ++ "/" ++ operation
